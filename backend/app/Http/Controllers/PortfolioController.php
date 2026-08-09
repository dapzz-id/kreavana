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
            'image' => 'required|image|mimes:jpeg,png,jpg,gif,webp|max:5120',
        ]);

        $path = $request->file('image')->store('portfolio', 'public');

        $item = PortfolioItem::create([
            'user_id' => $request->user()->id,
            'title' => $request->title,
            'category' => $request->category,
            'description' => $request->description,
            'image_url' => $path,
            'sort_order' => PortfolioItem::where('user_id', $request->user()->id)->count(),
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
            'image' => 'nullable|image|mimes:jpeg,png,jpg,gif,webp|max:5120',
        ]);

        $data = $request->only(['title', 'category', 'description']);

        if ($request->hasFile('image')) {
            if ($item->image_url) {
                Storage::disk('public')->delete($item->image_url);
            }
            $data['image_url'] = $request->file('image')->store('portfolio', 'public');
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
}
