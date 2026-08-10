<?php

namespace App\Services;

use App\Models\StorageFile;
use App\Models\StorageFileReference;
use App\Models\SystemLog;
use App\Models\User;
use App\Models\FileDeletionLog;
use App\Models\CreatorApplication;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Exception;

class StorageService extends BaseService
{
    /**
     * Store a file centrally with quota enforcement.
     */
    public function store(User $user, UploadedFile $file, string $category, string $visibility = 'private'): StorageFile
    {
        $size = $file->getSize();
        if ($size === false) {
            throw new Exception("Unable to determine file size.", 422);
        }

        $mimeType = $file->getClientMimeType();
        $originalName = $file->getClientOriginalName();
        $disk = $visibility === 'public' ? 'public' : 'private';
        $uuid = (string) Str::uuid();
        
        $extension = $file->getClientOriginalExtension();
        $storedName = $uuid . ($extension ? '.' . $extension : '');
        $path = $category . '/' . $storedName;

        return DB::transaction(function () use ($user, $file, $category, $visibility, $size, $mimeType, $originalName, $disk, $path, $storedName) {
            // Lock user row for update to prevent concurrent quota race condition
            $lockedUser = User::where('id', $user->id)->lockForUpdate()->first();

            $limit = $lockedUser->storage_limit_bytes;
            $currentUsed = $lockedUser->used_storage_bytes;

            if (($currentUsed + $size) > $limit) {
                throw new Exception("Storage quota exceeded. Used: {$currentUsed}, Limit: {$limit}, Required: {$size}", 422);
            }

            // Reserve quota immediately
            $lockedUser->used_storage_bytes += $size;
            $lockedUser->save();

            try {
                $checksum = hash_file('sha256', $file->getRealPath());

                // Store file physically
                $storedPath = $file->storeAs($category, $storedName, $disk);
                if (!$storedPath) {
                    throw new Exception("Failed to store file physically.");
                }

                // Save metadata
                $storageFile = StorageFile::create([
                    'user_id' => $lockedUser->id,
                    'original_name' => $originalName,
                    'stored_name' => $storedName,
                    'disk' => $disk,
                    'path' => $storedPath,
                    'category' => $category,
                    'visibility' => $visibility,
                    'mime_type' => $mimeType,
                    'size' => $size,
                    'checksum' => $checksum,
                ]);

                // Create initial physical ownership reference
                StorageFileReference::create([
                    'storage_file_id' => $storageFile->id,
                    'owner_type' => 'user',
                    'owner_id' => $lockedUser->id,
                    'reference_type' => 'creator_upload',
                    'reference_id' => null,
                ]);

                return $storageFile;
            } catch (Exception $e) {
                // Compensation: File was stored but DB failed, remove physical file
                if (Storage::disk($disk)->exists($path)) {
                    Storage::disk($disk)->delete($path);
                }
                throw $e;
            }
        });
    }

    /**
     * Delete a storage file and restore quota. Idempotent. Soft deletes the record.
     */
    public function delete(StorageFile $storageFile, User $user, ?string $reason = null, ?string $ip = null, ?string $userAgent = null): void
    {
        if ($storageFile->user_id !== $user->id) {
            throw new Exception("Unauthorized to delete this file.", 403);
        }

        DB::transaction(function () use ($storageFile, $user, $reason, $ip, $userAgent) {
            // Lock file to prevent concurrent deletes
            $lockedFile = StorageFile::where('id', $storageFile->id)->lockForUpdate()->first();
            if (!$lockedFile) {
                return; // Already deleted fully
            }

            // Lock user to safely update quota
            $lockedUser = User::where('id', $user->id)->lockForUpdate()->first();

            // Delete ownership reference for this file
            StorageFileReference::where('storage_file_id', $lockedFile->id)
                ->where('owner_id', $user->id)
                ->delete();

            // Delete physical file ONLY IF there are no other active references to this path (deduplication garbage collection)
            // Wait, we need to find if any other active StorageFile sharing the same physical path has active references.
            // But since StorageFile ID maps 1-1 to a StorageFileReference (for purchasers, they clone the StorageFile so they have their own StorageFile ID but same path),
            // We just need to check if ANY StorageFile with this path has active references, OR we can just check if any StorageFile with this path is NOT soft-deleted.
            // Actually, the new architecture says: "Cukup reference_count == 0 baru hapus fisik".
            // So we find all StorageFiles with the same path, and count their total references.
            $samePathFileIds = StorageFile::where('path', $lockedFile->path)->pluck('id');
            $activeReferences = StorageFileReference::whereIn('storage_file_id', $samePathFileIds)->count();
            
            if ($activeReferences === 0) {
                if (Storage::disk($lockedFile->disk)->exists($lockedFile->path)) {
                    Storage::disk($lockedFile->disk)->delete($lockedFile->path);
                }
            }

            // Decrement quota exactly once using actual size
            $lockedUser->used_storage_bytes = max(0, $lockedUser->used_storage_bytes - $lockedFile->size);
            $lockedUser->save();

            // Record Audit Log
            FileDeletionLog::create([
                'storage_file_id' => $lockedFile->id,
                'deleted_by' => $user->id,
                'reason' => $reason,
                'ip_address' => $ip,
                'user_agent' => $userAgent,
                'category' => $lockedFile->category,
                'file_size' => $lockedFile->size,
            ]);

            // Handle KYC verification rollback if KYC is deleted
            if ($lockedFile->category === 'kyc') {
                $lockedUser->is_creator_approved = false;
                $lockedUser->save();
                
                CreatorApplication::where('user_id', $user->id)
                    ->whereIn('status', ['pending', 'approved'])
                    ->update([
                        'status' => 'rejected',
                        'admin_note' => 'Dokumen KYC telah dihapus oleh pengguna. Silakan ajukan ulang dengan dokumen yang valid.'
                    ]);
            }

            // Soft delete metadata
            $lockedFile->delete();
        });
    }

    /**
     * Clone a storage file for a buyer.
     * Uses virtual quota (buyer quota is deducted as if they own it).
     */
    public function cloneToUser(StorageFile $sourceFile, User $buyer): StorageFile
    {
        return DB::transaction(function () use ($sourceFile, $buyer) {
            $lockedBuyer = User::where('id', $buyer->id)->lockForUpdate()->first();
            
            // Check quota
            $maxStorage = 5 * 1024 * 1024 * 1024; // 5GB limit, adjust based on your logic/subscription
            if ($lockedBuyer->used_storage_bytes + $sourceFile->size > $maxStorage) {
                throw new Exception("Storage quota exceeded.", 400);
            }
            
            // Deduct virtual quota
            $lockedBuyer->used_storage_bytes += $sourceFile->size;
            $lockedBuyer->save();

            // Clone metadata
            $clonedFile = StorageFile::create([
                'user_id' => $buyer->id,
                'original_name' => $sourceFile->original_name,
                'stored_name' => \Illuminate\Support\Str::uuid()->toString() . '.' . pathinfo($sourceFile->stored_name, PATHINFO_EXTENSION),
                'disk' => $sourceFile->disk,
                'path' => $sourceFile->path, // Same physical path (deduplication)
                'category' => 'purchased_asset',
                'visibility' => 'private',
                'mime_type' => $sourceFile->mime_type,
                'size' => $sourceFile->size,
                'checksum' => $sourceFile->checksum,
                'source_type' => 'purchased_clone',
                'source_storage_file_id' => $sourceFile->id,
            ]);

            StorageFileReference::create([
                'storage_file_id' => $clonedFile->id,
                'owner_type' => 'user',
                'owner_id' => $lockedBuyer->id,
                'reference_type' => 'purchased_clone',
                'reference_id' => null,
            ]);

            return $clonedFile;
        });
    }

    /**
     * Bulk clone multiple storage files for a buyer in a single transaction.
     * Prevents N+1 database queries.
     * Partial clone: successfully clones what fits in quota, returns pending for others.
     * 
     * @param \Illuminate\Support\Collection|array $sourceFiles
     * @param User $buyer
     * @return array ['cloned' => [StorageFile], 'pending' => [StorageFile]]
     */
    public function cloneManyToUser($sourceFiles, User $buyer): array
    {
        return DB::transaction(function () use ($sourceFiles, $buyer) {
            $lockedBuyer = User::where('id', $buyer->id)->lockForUpdate()->first();
            
            $limit = $lockedBuyer->storage_limit_bytes;
            $currentUsed = $lockedBuyer->used_storage_bytes;
            
            $cloned = [];
            $pending = [];
            
            $bulkFiles = [];
            $bulkReferences = [];
            $totalSizeUsed = 0;

            foreach ($sourceFiles as $sourceFile) {
                if (($currentUsed + $totalSizeUsed + $sourceFile->size) <= $limit) {
                    $totalSizeUsed += $sourceFile->size;
                    
                    $uuid = Str::uuid()->toString();
                    $clonedFile = [
                        'id' => $uuid,
                        'user_id' => $buyer->id,
                        'original_name' => $sourceFile->original_name,
                        'stored_name' => Str::uuid()->toString() . '.' . pathinfo($sourceFile->stored_name, PATHINFO_EXTENSION),
                        'disk' => $sourceFile->disk,
                        'path' => $sourceFile->path,
                        'category' => 'purchased_asset',
                        'visibility' => 'private',
                        'mime_type' => $sourceFile->mime_type,
                        'size' => $sourceFile->size,
                        'checksum' => $sourceFile->checksum,
                        'source_type' => 'purchased_clone',
                        'source_storage_file_id' => $sourceFile->id,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ];
                    $bulkFiles[] = $clonedFile;
                    
                    $bulkReferences[] = [
                        'id' => Str::uuid()->toString(),
                        'storage_file_id' => $uuid,
                        'owner_type' => 'user',
                        'owner_id' => $buyer->id,
                        'reference_type' => 'purchased_clone',
                        'reference_id' => null,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ];

                    $cloned[] = (object) $clonedFile;
                } else {
                    $pending[] = $sourceFile;
                }
            }
            
            if ($totalSizeUsed > 0) {
                $lockedBuyer->used_storage_bytes += $totalSizeUsed;
                $lockedBuyer->save();
                
                foreach (array_chunk($bulkFiles, 100) as $chunk) {
                    StorageFile::insert($chunk);
                }
                foreach (array_chunk($bulkReferences, 100) as $chunk) {
                    StorageFileReference::insert($chunk);
                }
            }

            return ['cloned' => $cloned, 'pending' => $pending];
        });
    }
}
