<?php

namespace App\Http\Controllers;

use App\Models\MarketplaceItem;
use App\Models\MarketplaceItemMedia;
use App\Models\MarketplaceReview;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Intervention\Image\ImageManager;
use Intervention\Image\Drivers\Gd\Driver;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use App\Models\PurchasedStorageAsset;
use App\Models\SystemLog;
use App\Models\StorageFile;
use App\Services\StorageService;

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
                    'media',
                    'reviews' => fn($q) => $q->with('user:id,name,username,avatar_url')->orderByDesc('created_at')->limit(10)])
            ->withCount('reviews')
            ->findOrFail($id);

        $data = $item->toArray();
        $user = Auth::guard('api')->user();

        if ($user) {
            $data['is_following'] = \App\Models\UserFollow::where('follower_id', $user->id)
                ->where('following_id', $item->user_id)
                ->exists();
        } else {
            $data['is_following'] = false;
        }

        // Watermark logic
        $isOwner = $user && $user->id === $item->user_id;
        $hasPurchased = $user && $item->purchases()->where('user_id', $user->id)->where('status', 'success')->exists();

        if ($item->type === 'paid' && !$isOwner && !$hasPurchased) {
            foreach ($data['media'] as &$media) {
                if ($media['watermarked_file_path']) {
                    $media['file_path'] = $media['watermarked_file_path'];
                }
            }
        }

        // Prefix URLs properly
        foreach ($data['media'] as &$media) {
            $media['file_path'] = url($media['file_path']);
            if ($media['watermarked_file_path']) {
                $media['watermarked_file_path'] = url($media['watermarked_file_path']);
            }
        }

        $data['has_purchased'] = $hasPurchased;

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
            'type' => 'required|in:free,paid',
            'price' => 'required_if:type,paid|numeric|min:0',
            'media' => 'nullable|array|max:5',
            'media.*' => 'image|mimes:jpeg,png,jpg,webp|max:5120', // max 5MB
        ]);

        $item = DB::transaction(function () use ($request) {
            $item = MarketplaceItem::create([
                'user_id' => Auth::id(),
                'title' => $request->title,
                'description' => $request->description,
                'category' => $request->category,
                'type' => $request->type,
                'price' => $request->type === 'paid' ? $request->price : 0,
            ]);

            if ($request->hasFile('media')) {
                $manager = new ImageManager(new Driver());
            $watermarkPath = public_path('assets/brandlogo.png');
            $hasWatermark = file_exists($watermarkPath);

            /** @var \App\Services\StorageService $storageService */
            $storageService = app(\App\Services\StorageService::class);

            foreach ($request->file('media') as $file) {
                // Store original file as PRIVATE so it is not directly accessible
                $originalStorageFile = $storageService->store($request->user(), $file, 'marketplace_original', 'private');

                $watermarkedPath = null;
                $watermarkedStorageFileId = null;

                $image = $manager->read($file->getRealPath());
                if ($hasWatermark) {
                    $image->place($watermarkPath, 'center', 50, 50, 50); // watermark
                } else {
                    // Fallback to text watermark if no image watermark found
                    $image->text('KREAVANA', $image->width() / 2, $image->height() / 2, function($font) {
                        $font->color('rgba(255, 255, 255, 0.5)');
                        $font->align('center');
                        $font->valign('middle');
                        $font->size(min($image->width(), $image->height()) / 10);
                    });
                }

                // Save watermarked to temp file
                $tempPath = sys_get_temp_dir() . '/' . Str::random(20) . '.jpg';
                file_put_contents($tempPath, (string) $image->toJpeg());
                $watermarkedFile = new \Illuminate\Http\UploadedFile($tempPath, 'watermarked.jpg', 'image/jpeg', null, true);

                // Store watermarked file as PUBLIC
                $watermarkedStorageFile = $storageService->store($request->user(), $watermarkedFile, 'marketplace_watermarked', 'public');
                $watermarkedPath = $watermarkedStorageFile->path;
                @unlink($tempPath);

                MarketplaceItemMedia::create([
                    'marketplace_item_id' => $item->id,
                    'file_path' => $originalStorageFile->id, // Storing ID instead of physical path for secure referencing
                    'watermarked_file_path' => 'storage/' . $watermarkedPath,
                    'file_type' => 'image',
                ]);
            }

            // Set cover image URL to the first media
            $firstMedia = MarketplaceItemMedia::where('marketplace_item_id', $item->id)->first();
            if ($firstMedia) {
                $item->update(['image_url' => url($firstMedia->watermarked_file_path ?? $firstMedia->file_path)]);
            }
            }

            return $item;
        });

        return response()->json([
            'status' => true,
            'message' => 'Karya berhasil dibuat.',
            'data' => $item->load('media'),
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

    public function review(Request $request, $id)
    {
        $request->validate([
            'rating' => 'required|integer|min:1|max:5',
            'review' => 'nullable|string|max:1000',
        ]);

        $item = MarketplaceItem::findOrFail($id);

        // Pastikan user sudah pernah membeli karya ini
        $hasPurchased = $item->purchases()->where('user_id', Auth::id())->where('status', 'success')->exists();
        if (!$hasPurchased && $item->type === 'paid') {
            return response()->json([
                'status' => false,
                'message' => 'Anda harus membeli karya ini terlebih dahulu untuk memberikan ulasan.',
            ], 403);
        }

        $review = DB::transaction(function () use ($item, $request) {
            $review = MarketplaceReview::updateOrCreate(
                ['marketplace_item_id' => $item->id, 'user_id' => Auth::id()],
                ['rating' => $request->rating, 'review' => $request->review]
            );

            $item->recalculateRating();
            return $review;
        });

        return response()->json([
            'status' => true,
            'message' => 'Ulasan berhasil disimpan.',
            'data' => $review->load('user:id,name,username,avatar_url'),
        ]);
    }

    public function purchases($id)
    {
        $item = MarketplaceItem::where('user_id', Auth::id())->findOrFail($id);
        $purchases = $item->purchases()->with('user:id,name,email,avatar_url')->get();

        return response()->json([
            'status' => true,
            'message' => 'Daftar pembeli berhasil dimuat.',
            'data' => $purchases,
        ]);
    }

    public function purchase(Request $request, $id)
    {
        $request->validate([
            'pin' => 'required|string|min:4|max:8',
        ]);

        $item = MarketplaceItem::active()->findOrFail($id);
        $buyer = Auth::guard('api')->user();
        $buyerId = $buyer->id;

        if (empty($buyer->wallet_pin)) {
            return response()->json([
                'status' => false,
                'message' => 'Wallet belum diaktifkan. Silakan aktifkan wallet dan atur PIN terlebih dahulu.',
                'error_code' => 'wallet_not_activated',
            ], 422);
        }

        if (!\Illuminate\Support\Facades\Hash::check($request->pin, $buyer->wallet_pin)) {
            return response()->json([
                'status' => false,
                'message' => 'PIN wallet salah.',
            ], 401);
        }

        if ($item->user_id === $buyerId) {
            return response()->json([
                'status' => false,
                'message' => 'Anda tidak bisa membeli karya Anda sendiri.',
            ], 400);
        }

        if ($item->type === 'free') {
            return response()->json([
                'status' => false,
                'message' => 'Karya ini gratis, Anda bisa langsung mengunduhnya.',
            ], 400);
        }

        // Quick check before transaction for UX (database constraint will also catch duplicates)
        $existing = $item->purchases()->where('user_id', $buyerId)->exists();
        if ($existing) {
            return response()->json([
                'status' => false,
                'message' => 'Anda sudah pernah membeli karya ini.',
            ], 400);
        }

        try {
            $purchase = DB::transaction(function () use ($item, $buyerId) {
                $sellerId = $item->user_id;

                // Deterministic lock ordering to prevent deadlocks
                $userIds = [$buyerId, $sellerId];
                sort($userIds);

                $lockedUsers = \App\Models\User::whereIn('id', $userIds)
                    ->lockForUpdate()
                    ->get()
                    ->keyBy('id');

                $buyer = $lockedUsers[$buyerId];
                $seller = $lockedUsers[$sellerId];

                $price = (float) $item->price;

                if ($buyer->balance < $price) {
                    throw new \Exception('Saldo tidak mencukupi untuk melakukan pembelian ini.', 400);
                }

                // Balance mutations
                $fee = $price * 0.05; // 5% platform fee
                $netAmount = $price - $fee;

                $buyer->balance -= $price;
                $buyer->save();

                $seller->balance += $netAmount;
                $seller->save();

                $purchase = $item->purchases()->create([
                    'user_id' => $buyerId,
                    'amount' => $price,
                    'status' => 'success',
                ]);

                $item->increment('order_count');

                // Wallet Transactions
                $refNumber = 'MP-' . strtoupper(\Illuminate\Support\Str::random(8)) . '-' . time();

                \App\Models\WalletTransaction::create([
                    'user_id' => $buyerId,
                    'type' => 'marketplace_purchase',
                    'amount' => $price,
                    'fee' => 0.00,
                    'payment_method' => 'wallet',
                    'payment_provider' => 'Kreavana Wallet',
                    'status' => 'completed',
                    'reference_number' => $refNumber . '-BUY-' . $purchase->id,
                    'description' => 'Pembelian karya "' . $item->title . '"',
                ]);

                \App\Models\WalletTransaction::create([
                    'user_id' => $sellerId,
                    'type' => 'marketplace_sale',
                    'amount' => $netAmount,
                    'fee' => $fee,
                    'payment_method' => 'wallet',
                    'payment_provider' => 'Kreavana Wallet',
                    'status' => 'completed',
                    'reference_number' => $refNumber . '-SELL-' . $purchase->id,
                    'description' => 'Penjualan karya "' . $item->title . '" kepada @' . $buyer->username,
                ]);

                \App\Models\CreatorPerformanceEvent::firstOrCreate(
                    [
                        'user_id' => $sellerId,
                        'event_type' => 'marketplace_sale',
                        'reference_id' => $purchase->id,
                    ],
                    [
                        'bonus_percentage' => 0.5,
                    ]
                );

                // Refresh seller to get the latest performance events
                $seller->refresh();
                $seller->updatePerformanceBoost();

                return $purchase;
            });

            \App\Models\Notification::create([
                'user_id' => $buyerId,
                'title' => 'Pembelian Berhasil',
                'message' => 'Anda berhasil membeli "' . $item->title . '" seharga Rp ' . number_format($item->price, 0, ',', '.') . '.',
                'type' => 'transaction',
                'data' => ['item_id' => $item->id, 'purchase_id' => $purchase->id],
                'is_read' => false,
                'created_at' => now(),
            ]);

            SystemLog::create([
                'id' => Str::uuid()->toString(),
                'user_id' => $buyerId,
                'action' => 'marketplace_purchase_completed',
                'title' => 'Marketplace Purchase Completed',
                'description' => 'User purchased item ' . $item->id,
                'type' => 'info',
                'metadata' => json_encode(['order_id' => $purchase->id, 'item_id' => $item->id]),
            ]);

            // Transaction 2: Clone Storage Assets
            \App\Models\AssetAccessPermission::firstOrCreate([
                'user_id' => $buyerId,
                'marketplace_item_id' => $item->id,
            ], [
                'can_download' => true,
                'can_clone' => true,
                'expires_at' => null,
            ]);

            $mediaFiles = MarketplaceItemMedia::where('marketplace_item_id', $item->id)->get();
            $sourceFileIds = [];
            foreach ($mediaFiles as $media) {
                if ($media->file_path) {
                    $sourceFileIds[] = $media->file_path;
                }
            }

            if (count($sourceFileIds) > 20) {
                // Dispatch Queue
                \App\Jobs\ClonePurchasedAssetsJob::dispatch($purchase->id, $buyerId, $item->id, $sourceFileIds);
                $purchase->update(['storage_sync_status' => 'pending']);

                SystemLog::create([
                    'id' => Str::uuid()->toString(),
                    'user_id' => $buyerId,
                    'action' => 'bulk_clone_started',
                    'title' => 'Bulk Clone Queued',
                    'description' => 'Queued bulk clone for order ' . $purchase->id,
                    'type' => 'info',
                    'metadata' => json_encode([
                        'order_id' => $purchase->id,
                        'total_files' => count($sourceFileIds),
                    ]),
                ]);
            } else {
                // Immediate bulk clone
                $storageService = app(\App\Services\StorageService::class);
                $buyerUser = \App\Models\User::find($buyerId);
                $sourceFiles = \App\Models\StorageFile::whereIn('id', $sourceFileIds)->get();

                // Idempotency: filter out already cloned
                $alreadyClonedIds = \App\Models\PurchasedStorageAsset::where('order_id', $purchase->id)
                    ->where('status', 'cloned')
                    ->pluck('source_storage_file_id')->toArray();

                $filesToClone = $sourceFiles->filter(function($f) use ($alreadyClonedIds) {
                    return !in_array($f->id, $alreadyClonedIds);
                });

                if ($filesToClone->isNotEmpty()) {
                    $cloneResult = $storageService->cloneManyToUser($filesToClone, $buyerUser);

                    $bulkAssets = [];
                    $now = now();

                    foreach ($cloneResult['cloned'] as $clonedItem) {
                        $bulkAssets[] = [
                            'id' => Str::uuid()->toString(),
                            'buyer_id' => $buyerId,
                            'order_id' => $purchase->id,
                            'marketplace_asset_id' => $item->id,
                            'source_storage_file_id' => $clonedItem->source_storage_file_id,
                            'cloned_storage_file_id' => $clonedItem->id,
                            'status' => 'cloned',
                            'clone_attempts' => 1,
                            'last_clone_attempt_at' => $now,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ];
                    }

                    foreach ($cloneResult['pending'] as $pendingItem) {
                        $bulkAssets[] = [
                            'id' => Str::uuid()->toString(),
                            'buyer_id' => $buyerId,
                            'order_id' => $purchase->id,
                            'marketplace_asset_id' => $item->id,
                            'source_storage_file_id' => $pendingItem->id,
                            'cloned_storage_file_id' => null,
                            'status' => 'pending_storage',
                            'clone_attempts' => 1,
                            'last_clone_attempt_at' => $now,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ];
                    }

                    // We use upsert or ignore if constraint exists
                    foreach (array_chunk($bulkAssets, 100) as $chunk) {
                        \App\Models\PurchasedStorageAsset::insertOrIgnore($chunk);
                    }

                    $totalSuccess = count($cloneResult['cloned']);
                    $totalPending = count($cloneResult['pending']);

                    if ($totalPending > 0 && $totalSuccess > 0) {
                        $purchase->update(['storage_sync_status' => 'partial']);
                    } elseif ($totalPending > 0 && $totalSuccess === 0) {
                        $purchase->update(['storage_sync_status' => 'pending']);
                    } else {
                        $purchase->update(['storage_sync_status' => 'completed']);
                    }

                    SystemLog::create([
                        'id' => Str::uuid()->toString(),
                        'user_id' => $buyerId,
                        'action' => 'bulk_clone_completed',
                        'title' => 'Bulk Clone Completed',
                        'description' => 'Successfully cloned asset bundle for order ' . $purchase->id,
                        'type' => 'info',
                        'metadata' => json_encode([
                            'order_id' => $purchase->id,
                            'total_files' => $filesToClone->count(),
                            'success' => $totalSuccess,
                            'pending' => $totalPending
                        ]),
                    ]);
                } else {
                    $purchase->update(['storage_sync_status' => 'completed']);
                }
            }

            return response()->json([
                'status' => true,
                'message' => 'Berhasil membeli karya.',
                'data' => $purchase,
            ]);

        } catch (\Illuminate\Database\QueryException $e) {
            // Catch duplicate entry for unique constraint
            if (isset($e->errorInfo[1]) && ($e->errorInfo[1] === 1062 || $e->errorInfo[1] === 19)) {
                return response()->json([
                    'status' => false,
                    'message' => 'Anda sudah pernah membeli karya ini.',
                ], 400);
            }
            return response()->json([
                'status' => false,
                'message' => 'Terjadi kesalahan sistem saat memproses pembelian.',
            ], 500);
        } catch (\Exception $e) {
            $code = $e->getCode() ?: 500;
            if ($code < 100 || $code > 599) $code = 500;
            return response()->json([
                'status' => false,
                'message' => $e->getMessage(),
            ], (int) $code);
        }
    }
}
