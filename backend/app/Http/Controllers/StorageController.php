<?php

namespace App\Http\Controllers;

use App\Models\StorageFile;
use App\Models\User;
use App\Models\Message;
use App\Services\StorageService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

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
        
        $files = StorageFile::where('user_id', $user->id)
            ->select('id', 'original_name', 'size', 'mime_type', 'category', 'visibility', 'created_at')
            ->orderBy('created_at', 'desc')
            ->paginate(20);

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
            $this->storageService->delete($storageFile, $user);
            return response()->json(['message' => 'File deleted successfully.']);
        } catch (\Exception $e) {
            return response()->json(['message' => $e->getMessage()], 400);
        }
    }

    public function downloadChatAttachment(Request $request, $id)
    {
        $user = $request->user();

        $storageFile = StorageFile::where('id', $id)
            ->where('category', 'chat_attachment')
            ->where('visibility', 'private')
            ->first();

        if (!$storageFile) {
            return response()->json(['message' => 'Attachment not found.'], 404);
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
}
