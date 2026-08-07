<?php

namespace App\Http\Controllers;

use App\Models\MarketplaceItem;
use App\Models\MarketplaceReview;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class MarketplaceController extends Controller
{
    public function index(Request $request)
    {
        $query = MarketplaceItem::active()
            ->with('user:id,name,username,avatar_url')
            ->category($request->category)
            ->search($request->search);

        $sortBy = $request->get('sort', 'latest');
        $query = match ($sortBy) {
            'popular' => $query->orderByDesc('order_count'),
            'rating' => $query->orderByDesc('rating'),
            'price_low' => $query->orderBy('price'),
            'price_high' => $query->orderByDesc('price'),
            default => $query->orderByDesc('created_at'),
        };

        $items = $query->paginate($request->get('per_page', 20));

        return response()->json([
            'status' => true,
            'data' => $items,
        ]);
    }

    public function featured()
    {
        $items = MarketplaceItem::active()
            ->featured()
            ->with('user:id,name,username,avatar_url')
            ->orderByDesc('rating')
            ->limit(6)
            ->get();

        return response()->json([
            'status' => true,
            'data' => $items,
        ]);
    }

    public function categories()
    {
        $categories = MarketplaceItem::active()
            ->selectRaw('category, COUNT(*) as count')
            ->groupBy('category')
            ->orderByDesc('count')
            ->get();

        return response()->json([
            'status' => true,
            'data' => $categories,
        ]);
    }

    public function show($id)
    {
        $item = MarketplaceItem::active()
            ->with(['user:id,name,username,avatar_url,role,sub_role,phone,email',
                    'reviews' => fn($q) => $q->with('user:id,name,username,avatar_url')->orderByDesc('created_at')->limit(10),
                    'reviews.user:id,name,username,avatar_url'])
            ->withCount('reviews')
            ->findOrFail($id);

        $data = $item->toArray();

        if ($user = Auth::user()) {
            $data['is_following'] = \App\Models\UserFollow::where('follower_id', $user->id)
                ->where('following_id', $item->user_id)
                ->exists();
        } else {
            $data['is_following'] = false;
        }

        return response()->json([
            'status' => true,
            'data' => $data,
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:200',
            'description' => 'nullable|string|max:2000',
            'category' => 'required|string|in:Fotografi,Videografi,Desain,Konten,Branding',
            'price' => 'required|numeric|min:0',
            'image_url' => 'nullable|url|max:500',
        ]);

        $item = MarketplaceItem::create([
            'user_id' => Auth::id(),
            'title' => $request->title,
            'description' => $request->description,
            'category' => $request->category,
            'price' => $request->price,
            'image_url' => $request->image_url,
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Karya berhasil dibuat.',
            'data' => $item,
        ], 201);
    }

    public function update(Request $request, $id)
    {
        $item = MarketplaceItem::where('user_id', Auth::id())->findOrFail($id);

        $request->validate([
            'title' => 'sometimes|string|max:200',
            'description' => 'nullable|string|max:2000',
            'category' => 'sometimes|string|in:Fotografi,Videografi,Desain,Konten,Branding',
            'price' => 'sometimes|numeric|min:0',
            'image_url' => 'nullable|url|max:500',
            'is_active' => 'sometimes|boolean',
        ]);

        $item->update($request->only([
            'title', 'description', 'category', 'price', 'image_url', 'is_active',
        ]));

        return response()->json([
            'status' => true,
            'message' => 'Karya berhasil diperbarui.',
            'data' => $item,
        ]);
    }

    public function destroy($id)
    {
        $item = MarketplaceItem::where('user_id', Auth::id())->findOrFail($id);
        $item->delete();

        return response()->json([
            'status' => true,
            'message' => 'Karya berhasil dihapus.',
        ]);
    }

    public function review(Request $request, $itemId)
    {
        $request->validate([
            'rating' => 'required|integer|min:1|max:5',
            'comment' => 'nullable|string|max:500',
        ]);

        $item = MarketplaceItem::active()->findOrFail($itemId);

        $review = MarketplaceReview::updateOrCreate(
            ['marketplace_item_id' => $itemId, 'user_id' => Auth::id()],
            ['rating' => $request->rating, 'comment' => $request->comment],
        );

        $item->recalculateRating();

        return response()->json([
            'status' => true,
            'message' => 'Review berhasil.',
            'data' => $review->load('user:id,name,username,avatar_url'),
        ]);
    }
}
