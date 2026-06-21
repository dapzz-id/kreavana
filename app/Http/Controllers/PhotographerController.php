<?php

namespace App\Http\Controllers;

use App\Repositories\Contracts\PhotoRepositoryInterface;
use App\Repositories\Contracts\PurchaseRepositoryInterface;
use App\Services\WatermarkService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\File;

/**
 * PhotographerController — Photographer-Role Operations
 *
 * SRP : Only handles photo management for the authenticated photographer.
 * DIP : Depends on repository interfaces, not raw Eloquent.
 */
class PhotographerController extends Controller
{
    public function __construct(
        private readonly WatermarkService          $watermarkService,
        private readonly PhotoRepositoryInterface  $photoRepository,
        private readonly PurchaseRepositoryInterface $purchaseRepository,
    ) {}

    /**
     * Show Photographer dashboard with uploaded photos & earnings stats.
     */
    public function dashboard()
    {
        $user   = Auth::user();
        $photos = $this->photoRepository->getByPhotographer($user->id);

        $photoIds      = $photos->pluck('id')->toArray();
        $sales         = $this->purchaseRepository->getByPhotoIds($photoIds);
        $salesCount    = $sales->count();
        $uploadedCount = $photos->count();
        $totalEarnings = $user->balance; // Decrypted from secure ledger

        return view('photographer.dashboard', compact('photos', 'uploadedCount', 'salesCount', 'totalEarnings'));
    }

    /**
     * Upload and process a new photo (with optional watermark for paid content).
     */
    public function uploadPhoto(Request $request)
    {
        $request->validate([
            'title'       => 'required|string|max:255',
            'description' => 'nullable|string|max:1000',
            'photo'       => 'required|image|mimes:jpeg,png,jpg,webp|max:10240',
            'price'       => 'nullable|numeric|min:0',
            'tags'        => 'nullable|string|max:255',
        ]);

        $user     = Auth::user();
        $file     = $request->file('photo');
        $filename = time() . '_' . str_replace(' ', '_', $file->getClientOriginalName());

        // 1. Save original to private storage (not publicly accessible)
        $privatePath = storage_path('app/private/originals');
        File::ensureDirectoryExists($privatePath);
        $originalFilePath = $privatePath . '/' . $filename;
        $file->move($privatePath, $filename);

        // 2. Determine pricing and sale flag
        $isForSale = $request->boolean('is_for_sale');
        $price     = $isForSale ? (float) ($request->price ?? 0.00) : 0.00;
        if ($price <= 0) $isForSale = false;

        // 3. Create watermarked version for public display
        $publicPath = storage_path('app/public/watermarked');
        File::ensureDirectoryExists($publicPath);
        $watermarkedFilePath = $publicPath . '/' . $filename;

        if ($isForSale) {
            $this->watermarkService->applyWatermark($originalFilePath, $watermarkedFilePath);
        } else {
            File::copy($originalFilePath, $watermarkedFilePath);
        }

        // 4. Persist photo entry to DB via repository
        $this->photoRepository->create([
            'user_id'          => $user->id,
            'title'            => $request->title,
            'description'      => $request->description,
            'original_path'    => 'originals/' . $filename,
            'watermarked_path' => 'watermarked/' . $filename,
            'price'            => $price,
            'is_for_sale'      => $isForSale,
            'tags'             => $request->tags ?? '',
        ]);

        return redirect()->route('photographer.dashboard')
            ->with('success', 'Foto berhasil diunggah dan siap dipasarkan.');
    }
}
