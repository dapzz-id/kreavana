<?php

namespace App\Http\Controllers;

use App\Models\PortfolioItem;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class PortfolioController extends Controller
{
    public function index(Request $request)
    {
        $items = PortfolioItem::where('user_id', $request->user()->id)
            ->orderBy('sort_order')
            ->get();

        return response()->json([
            'status' => true,
            'data' => $items,
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:255',
            'category' => 'nullable|string|max:100',
            'description' => 'nullable|string|max:500',
            'image' => 'nullable|image|mimes:jpeg,png,jpg,gif,webp|max:20480',
            'event_date' => 'nullable|date',
            'location' => 'nullable|string|max:150',
            'source' => 'nullable|in:external,internal',
            'client_name' => 'nullable|string|max:150',
        ]);

        $imageUrl = null;
        if ($request->hasFile('image')) {
            /** @var \App\Services\StorageService $storageService */
            $storageService = app(\App\Services\StorageService::class);
            $storageFile = $storageService->store($request->user(), $request->file('image'), 'portfolio', 'public');
            $imageUrl = $storageFile->path;
        }

        $item = PortfolioItem::create([
            'user_id' => $request->user()->id,
            'title' => $request->title,
            'category' => $request->category,
            'description' => $request->description,
            'image_url' => $imageUrl,
            'sort_order' => PortfolioItem::where('user_id', $request->user()->id)->count(),
            'event_date' => $request->event_date,
            'location' => $request->location,
            'source' => $request->input('source', 'external'),
            'verification_status' => 'self_reported',
            'client_name' => $request->client_name,
        ]);

        return response()->json([
            'status' => true,
            'data' => $item,
            'message' => 'Portfolio item berhasil ditambahkan.',
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $item = PortfolioItem::where('user_id', $request->user()->id)->findOrFail($id);

        $request->validate([
            'title' => 'sometimes|string|max:255',
            'category' => 'nullable|string|max:100',
            'description' => 'nullable|string|max:500',
            'image' => 'nullable|image|mimes:jpeg,png,jpg,gif,webp|max:20480',
            'event_date' => 'nullable|date',
            'location' => 'nullable|string|max:150',
            'source' => 'nullable|in:external,internal',
            'client_name' => 'nullable|string|max:150',
        ]);

        $data = $request->only(['title', 'category', 'description', 'event_date', 'location', 'source', 'client_name']);

        if ($request->hasFile('image')) {
            /** @var \App\Services\StorageService $storageService */
            $storageService = app(\App\Services\StorageService::class);
            $storageFile = $storageService->store($request->user(), $request->file('image'), 'portfolio', 'public');
            
            // Delete old physical file using Storage::disk('public')->delete if needed, 
            // but we really should fetch the old StorageFile and use StorageService->delete.
            // For now, we update image_url.
            $data['image_url'] = $storageFile->path;
        }

        $item->update($data);

        return response()->json([
            'status' => true,
            'data' => $item,
            'message' => 'Portfolio item berhasil diperbarui.',
        ]);
    }

    public function destroy(Request $request, $id)
    {
        $item = PortfolioItem::where('user_id', $request->user()->id)->findOrFail($id);

        if ($item->image_url) {
            Storage::disk('public')->delete($item->image_url);
        }

        $item->delete();

        return response()->json([
            'status' => true,
            'message' => 'Portfolio item berhasil dihapus.',
        ]);
    }

    public function reorder(Request $request)
    {
        $request->validate([
            'order' => 'required|array',
            'order.*' => 'integer',
        ]);

        foreach ($request->order as $index => $itemId) {
            PortfolioItem::where('user_id', $request->user()->id)
                ->where('id', $itemId)
                ->update(['sort_order' => $index]);
        }

        return response()->json([
            'status' => true,
            'message' => 'Urutan portfolio berhasil diperbarui.',
        ]);
    }

    /**
     * Public: serve portfolio image with CORS headers.
     */
    public function showAsset(Request $request, string $file)
    {
        if (!preg_match('/^[a-zA-Z0-9_\-\.]+\.(jpg|jpeg|png|gif|webp|svg|heic)$/i', $file)) {
            abort(404);
        }

        $possiblePaths = [
            storage_path('app/public/portfolio/' . $file),
            public_path('storage/portfolio/' . $file),
            public_path('portfolio/' . $file),
        ];

        $path = null;
        foreach ($possiblePaths as $p) {
            if (file_exists($p)) {
                $path = $p;
                break;
            }
        }

        if (!$path) {
            abort(404);
        }

        $mime = match (strtolower(pathinfo($file, PATHINFO_EXTENSION))) {
            'png' => 'image/png',
            'gif' => 'image/gif',
            'webp' => 'image/webp',
            'svg' => 'image/svg+xml',
            default => 'image/jpeg',
        };

        return response()->file($path, [
            'Content-Type' => $mime,
            'Cache-Control' => 'public, max-age=31536000',
        ]);
    }
}
