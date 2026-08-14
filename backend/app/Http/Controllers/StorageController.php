<?php

namespace App\Http\Controllers;

use App\Models\StorageFile;
use App\Models\User;
use App\Models\Message;
use App\Services\StorageService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use App\Models\PurchasedStorageAsset;
use App\Models\SystemLog;

class StorageController extends Controller
{
    protected StorageService $storageService;

    public function __construct(StorageService $storageService)
    {
        $this->storageService = $storageService;
    }

    public function history(Request $request)
    {
        $user = $request->user();
        
        $filesQuery = DB::table('storage_files')
            ->where('user_id', $user->id)
            ->whereNull('deleted_at')
            ->select('id', 'original_name', 'size', 'mime_type', 'category', 'visibility', 'created_at', DB::raw("'cloned' as status"));

        $pendingQuery = DB::table('purchased_storage_assets')
            ->join('storage_files', 'purchased_storage_assets.source_storage_file_id', '=', 'storage_files.id')
            ->where('purchased_storage_assets.buyer_id', $user->id)
            ->where('purchased_storage_assets.status', 'pending_storage')
            ->select(
                'purchased_storage_assets.id', 
                'storage_files.original_name', 
                'storage_files.size', 
                'storage_files.mime_type', 
                DB::raw("'purchased_asset' as category"), 
                DB::raw("'private' as visibility"), 
                'purchased_storage_assets.created_at', 
                'purchased_storage_assets.status'
            );

        $query = $filesQuery->unionAll($pendingQuery);
        $combinedQuery = DB::table(DB::raw("({$query->toSql()}) as combined"))
            ->mergeBindings($query);

        // Filters
        if ($request->filled('type') && $request->type !== 'Semua') {
            $type = strtolower($request->type);
            if ($type === 'foto') {
                $combinedQuery->where('mime_type', 'like', 'image/%');
            } elseif ($type === 'video') {
                $combinedQuery->where('mime_type', 'like', 'video/%');
            } elseif ($type === 'audio') {
                $combinedQuery->where('mime_type', 'like', 'audio/%');
            } elseif ($type === 'dokumen') {
                $combinedQuery->whereIn('mime_type', ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'text/plain']);
            } else {
                $combinedQuery->where('mime_type', 'not like', 'image/%')
                              ->where('mime_type', 'not like', 'video/%')
                              ->where('mime_type', 'not like', 'audio/%');
            }
        }

        if ($request->filled('category') && $request->category !== 'Semua') {
            $cat = $request->category;
            // Map UI category to DB category
            if ($cat === 'Upload Saya') $combinedQuery->where('category', 'creator_upload'); // Or similar
            elseif ($cat === 'Purchased Asset') $combinedQuery->where('category', 'purchased_asset');
            elseif ($cat === 'Chat Attachment') $combinedQuery->where('category', 'chat_attachment');
            elseif ($cat === 'Portfolio') $combinedQuery->where('category', 'portfolio');
            elseif ($cat === 'Marketplace') $combinedQuery->whereIn('category', ['marketplace_original', 'marketplace_watermarked']);
        }

        // Sorting
        $sort = $request->get('sort', 'Terbaru');
        if ($sort === 'Terbaru') $combinedQuery->orderBy('created_at', 'desc');
        elseif ($sort === 'Terlama') $combinedQuery->orderBy('created_at', 'asc');
        elseif ($sort === 'A-Z') $combinedQuery->orderBy('original_name', 'asc');
        elseif ($sort === 'Z-A') $combinedQuery->orderBy('original_name', 'desc');
        elseif ($sort === 'Ukuran terbesar') $combinedQuery->orderBy('size', 'desc');
        elseif ($sort === 'Ukuran terkecil') $combinedQuery->orderBy('size', 'asc');

        $files = $combinedQuery->paginate(20);

        return response()->json([
            'used_storage_bytes' => (int) $user->used_storage_bytes,
            'storage_limit_bytes' => (int) $user->storage_limit_bytes,
            'remaining_storage_bytes' => max(0, $user->storage_limit_bytes - $user->used_storage_bytes),
            'files' => $files,
        ]);
    }

    public function destroy(Request $request, $id)
    {
        $user = $request->user();
        
        $storageFile = StorageFile::where('user_id', $user->id)
            ->where('id', $id)
            ->first();

        if (!$storageFile) {
            return response()->json(['message' => 'File not found or already deleted.'], 404);
        }

        try {
            $this->storageService->delete(
                $storageFile,
                $user,
                $request->input('reason', 'User requested deletion via Storage Manager'),
                $request->ip(),
                $request->userAgent()
            );
            return response()->json(['message' => 'File deleted successfully.']);
        } catch (\Exception $e) {
            return response()->json(['message' => $e->getMessage()], 400);
        }
    }

    public function downloadChatAttachment(Request $request, $id)
    {
        $user = $request->user();

        $storageFile = StorageFile::withTrashed()
            ->where('id', $id)
            ->where('category', 'chat_attachment')
            ->where('visibility', 'private')
            ->first();

        if (!$storageFile) {
            return response()->json(['message' => 'Attachment not found.'], 404);
        }

        if ($storageFile->trashed()) {
            return response()->json(['message' => 'Media telah dihapus'], 410);
        }

        // Verify conversation ownership. We check if the attachment is referenced in any message in a chat where user is participant.
        // Assuming $storageFile->id is stored in `media_url` or similar reference in messages.
        // In our MessageService we saved `$storageFile->id` into `media_url` instead of URL string.
        $message = Message::where('media_url', $storageFile->id)->first();
        if (!$message) {
            return response()->json(['message' => 'Attachment message reference not found.'], 404);
        }

        $chat = $message->chat;
        $isParticipant = $chat->participants()->where('user_id', $user->id)->exists();
        
        if (!$isParticipant) {
            return response()->json(['message' => 'Forbidden'], 403);
        }

        if (!Storage::disk('private')->exists($storageFile->path)) {
            return response()->json(['message' => 'Physical file not found.'], 404);
        }

        return Storage::disk('private')->download($storageFile->path, $storageFile->original_name, [
            'Content-Type' => $storageFile->mime_type,
        ]);
    }

    public function status(Request $request, $id)
    {
        // Try to find by ID or stored_name (to support frontend url extraction)
        $storageFile = StorageFile::withTrashed()
            ->where('id', $id)
            ->orWhere('stored_name', $id)
            ->first();

        if (!$storageFile) {
            return response()->json(['deleted' => true, 'message' => 'Media tidak ditemukan atau telah dihapus permanen.'], 404);
        }

        // Authorization check for private media
        if ($storageFile->visibility === 'private') {
            $user = auth('sanctum')->user();
            if (!$user || $storageFile->user_id !== $user->id) {
                // Return 404 to obscure existence from unauthorized users
                return response()->json(['deleted' => true, 'message' => 'Media tidak ditemukan atau telah dihapus permanen.'], 404);
            }
        }

        if ($storageFile->trashed()) {
            return response()->json([
                'deleted' => true,
                'message' => 'Media telah dihapus',
                'deleted_at' => $storageFile->deleted_at
            ]);
        }

        return response()->json([
            'deleted' => false,
            'message' => 'Media aktif',
            'url' => Storage::disk($storageFile->disk)->url($storageFile->path)
        ]);
    }

    public function retryPurchasedClone(Request $request, $id)
    {
        $user = $request->user();

        try {
            $purchasedAsset = DB::transaction(function () use ($id, $user) {
                $asset = PurchasedStorageAsset::where('id', $id)
                    ->where('buyer_id', $user->id)
                    ->lockForUpdate()
                    ->firstOrFail();

                if ($asset->status === 'cloned') {
                    throw new \Exception('Aset sudah berhasil disimpan.', 400);
                }

                $sourceStorageFile = $asset->sourceFile;
                if (!$sourceStorageFile) {
                    throw new \Exception('File sumber tidak ditemukan.', 404);
                }

                $clonedFile = $this->storageService->cloneToUser($sourceStorageFile, $user);
                
                $asset->cloned_storage_file_id = $clonedFile->id;
                $asset->status = 'cloned';
                $asset->clone_attempts += 1;
                $asset->last_clone_attempt_at = now();
                $asset->save();

                SystemLog::create([
                    'id' => Str::uuid()->toString(),
                    'user_id' => $user->id,
                    'action' => 'storage_clone_retry',
                    'title' => 'Storage Clone Retry',
                    'description' => 'Successfully retried cloning asset ' . $asset->id,
                    'type' => 'info',
                    'metadata' => json_encode(['purchased_asset_id' => $asset->id]),
                ]);

                return $asset;
            });

            return response()->json([
                'status' => true,
                'message' => 'Berhasil menyimpan aset ke Storage Manager Anda.',
                'data' => $purchasedAsset
            ]);

        } catch (\Exception $e) {
            $asset = PurchasedStorageAsset::where('id', $id)->where('buyer_id', $user->id)->first();
            if ($asset) {
                $asset->increment('clone_attempts');
                $asset->update(['last_clone_attempt_at' => now()]);
            }

            $code = $e->getCode() ?: 500;
            if ($code < 100 || $code > 599) $code = 500;
            return response()->json([
                'status' => false,
                'message' => $e->getMessage() ?: 'Gagal menyimpan aset karena kuota penuh atau kesalahan sistem.',
            ], $code);
        }
    }

    public function downloadPurchasedAsset(Request $request, $id)
    {
        $user = $request->user();
        
        $asset = PurchasedStorageAsset::with(['order', 'sourceFile', 'clonedFile'])
            ->where('id', $id)
            ->where('buyer_id', $user->id)
            ->firstOrFail();
            
        $permission = \App\Models\AssetAccessPermission::where('user_id', $user->id)
            ->where('marketplace_item_id', $asset->marketplace_asset_id)
            ->first();

        if (!$permission || !$permission->can_download) {
             return response()->json(['message' => 'Unauthorized or access revoked.'], 403);
        }

        if ($asset->order->status !== 'success') {
            return response()->json(['message' => 'Payment not successful'], 403);
        }
        
        // We can serve the file directly since we know they own the purchase
        $fileToServe = $asset->clonedFile ?? $asset->sourceFile;
        
        if (!$fileToServe || $fileToServe->trashed()) {
             return response()->json(['message' => 'File not found or deleted'], 404);
        }

        \App\Models\MediaDownloadLog::create([
            'id' => \Illuminate\Support\Str::uuid()->toString(),
            'buyer_id' => $user->id,
            'purchased_asset_id' => $asset->id,
            'source_file_id' => $asset->sourceFile->id ?? $fileToServe->id,
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'download_type' => $asset->clonedFile ? 'cloned' : 'source_creator',
        ]);

        return Storage::disk($fileToServe->disk)->download($fileToServe->path, $fileToServe->original_name, [
            'Content-Type' => $fileToServe->mime_type,
        ]);
    }
}
