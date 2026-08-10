<?php

namespace App\Services;

use App\Models\StorageFile;
use App\Models\User;
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
     * Delete a storage file and restore quota. Idempotent.
     */
    public function delete(StorageFile $storageFile, User $user): void
    {
        if ($storageFile->user_id !== $user->id) {
            throw new Exception("Unauthorized to delete this file.", 403);
        }

        DB::transaction(function () use ($storageFile, $user) {
            // Lock file to prevent concurrent deletes
            $lockedFile = StorageFile::where('id', $storageFile->id)->lockForUpdate()->first();
            if (!$lockedFile) {
                return; // Already deleted fully
            }

            // Lock user to safely update quota
            $lockedUser = User::where('id', $user->id)->lockForUpdate()->first();

            // Delete physical file
            if (Storage::disk($lockedFile->disk)->exists($lockedFile->path)) {
                Storage::disk($lockedFile->disk)->delete($lockedFile->path);
            }

            // Decrement quota exactly once using actual size
            $lockedUser->used_storage_bytes = max(0, $lockedUser->used_storage_bytes - $lockedFile->size);
            $lockedUser->save();

            // Delete metadata (hard delete for accurate sum)
            $lockedFile->forceDelete();
        });
    }
}
