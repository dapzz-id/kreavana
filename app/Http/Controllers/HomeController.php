<?php

namespace App\Http\Controllers;

use App\Models\Photo;
use App\Repositories\Contracts\PhotoRepositoryInterface;
use App\Repositories\Contracts\SocialRepositoryInterface;
use App\Repositories\Contracts\PhotographerRequestRepositoryInterface;
use App\Repositories\Contracts\PurchaseRepositoryInterface;
use App\Services\AISearchService;
use App\Notifications\SystemNotification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\File;

class HomeController extends Controller
{
    public function __construct(
        private readonly AISearchService                        $aiSearchService,
        private readonly PhotoRepositoryInterface               $photoRepository,
        private readonly SocialRepositoryInterface             $socialRepository,
        private readonly PhotographerRequestRepositoryInterface $photographerRequestRepository,
        private readonly PurchaseRepositoryInterface           $purchaseRepository,
    ) {}

    /**
     * Show landing page with feed & AI search capabilities.
     */
    public function index(Request $request)
    {
        $query      = $request->input('q');
        $searchType = null;

        if ($request->hasFile('lens_image')) {
            $searchType = 'lens';
            $photos     = $this->aiSearchService->searchByImage($request->file('lens_image'));
        } elseif (!empty($query)) {
            $searchType = 'text';
            $photos     = $this->aiSearchService->searchByText($query);
        } else {
            $photos = Photo::with('photographer')->withCount('likes')->latest()->get();
        }

        return view('home', compact('photos', 'query', 'searchType'));
    }

    /**
     * View specific photo details with social state for the current user.
     */
    public function showPhoto(int $id)
    {
        $photo       = $this->photoRepository->findByIdWithRelations($id, ['photographer', 'comments.user']);
        $hasLiked    = false;
        $hasSaved    = false;
        $hasPurchased = false;

        if (Auth::check()) {
            $user         = Auth::user();
            $hasLiked     = (bool) $this->socialRepository->findLike($user->id, $id);
            $hasSaved     = (bool) $this->socialRepository->findSave($user->id, $id);
            $hasPurchased = $user->hasPurchased($photo->id);
        }

        return view('photo.show', compact('photo', 'hasLiked', 'hasSaved', 'hasPurchased'));
    }

    /**
     * Toggle like on a photo (AJAX).
     */
    public function likePhoto(Request $request, int $id)
    {
        if (!Auth::check()) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $userId   = Auth::id();
        $existing = $this->socialRepository->findLike($userId, $id);

        if ($existing) {
            $this->socialRepository->deleteLike($existing);
            $liked = false;
        } else {
            $this->socialRepository->createLike($userId, $id);
            $liked = true;

            // Trigger notification
            $photo = $this->photoRepository->findById($id);
            if ($photo && $photo->user_id !== $userId) {
                $photo->photographer->notify(new SystemNotification(
                    'Foto Disukai',
                    Auth::user()->name . ' menyukai foto Anda: "' . $photo->title . '"',
                    route('photo.show', $photo->id),
                    'like'
                ));
            }
        }

        return response()->json([
            'success'     => true,
            'liked'       => $liked,
            'likes_count' => $this->socialRepository->countLikes($id),
        ]);
    }

    /**
     * Submit a comment on a photo.
     */
    public function commentPhoto(Request $request, int $id)
    {
        if (!Auth::check()) {
            return redirect()->back()->with('error', 'Silakan login untuk berkomentar.');
        }

        $request->validate(['content' => 'required|string|max:500']);

        $this->socialRepository->createComment(Auth::id(), $id, $request->content);

        // Trigger notification
        $photo = $this->photoRepository->findById($id);
        if ($photo && $photo->user_id !== Auth::id()) {
            $photo->photographer->notify(new SystemNotification(
                'Komentar Baru',
                Auth::user()->name . ' mengomentari foto Anda: "' . $photo->title . '"',
                route('photo.show', $photo->id),
                'comment'
            ));
        }

        return redirect()->back()->with('success', 'Komentar berhasil ditambahkan.');
    }

    /**
     * Toggle bookmark/save a photo (AJAX).
     */
    public function savePhoto(Request $request, int $id)
    {
        if (!Auth::check()) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $userId   = Auth::id();
        $existing = $this->socialRepository->findSave($userId, $id);

        if ($existing) {
            $this->socialRepository->deleteSave($existing);
            $saved = false;
        } else {
            $this->socialRepository->createSave($userId, $id);
            $saved = true;
        }

        return response()->json(['success' => true, 'saved' => $saved]);
    }

    /**
     * Securely download the original unwatermarked image (post-purchase only).
     */
    public function downloadPhoto(int $id)
    {
        $photo = $this->photoRepository->findById($id);

        if (!$photo) {
            abort(404);
        }

        if (!Auth::check()) {
            return redirect()->route('login')->with('error', 'Anda harus masuk terlebih dahulu.');
        }

        if (!Auth::user()->hasPurchased($photo->id)) {
            return redirect()->back()->with('error', 'Anda harus membeli foto ini sebelum mengunduh.');
        }

        $filePath = storage_path('app/private/' . $photo->original_path);

        if (!File::exists($filePath)) {
            return redirect()->back()->with('error', 'File asli tidak ditemukan di server.');
        }

        $extension = pathinfo($filePath, PATHINFO_EXTENSION);
        $fileName  = str_replace(' ', '_', $photo->title) . '_original.' . $extension;

        return response()->download($filePath, $fileName);
    }

    /**
     * Show logged-in user's profile page.
     */
    public function showProfile()
    {
        if (!Auth::check()) {
            return redirect()->route('login');
        }

        $user                = Auth::user();
        $purchasedPhotos     = $this->purchaseRepository->getByUser($user->id)->map->photo;
        $savedPhotoIds       = $this->socialRepository->getSavedPhotoIds($user->id);
        $savedPhotos         = Photo::with('photographer')->whereIn('id', $savedPhotoIds)->get();
        $photographerRequest = $this->photographerRequestRepository->getForUser($user->id);

        return view('profile', compact('user', 'purchasedPhotos', 'savedPhotos', 'photographerRequest'));
    }

    /**
     * Submit a request to become a photographer (uploads KTP & NPWP).
     */
    public function requestPhotographer(Request $request)
    {
        if (!Auth::check()) {
            return redirect()->route('login');
        }

        $request->validate([
            'ktp'  => 'required|image|mimes:jpeg,png,jpg,pdf|max:2048',
            'npwp' => 'required|image|mimes:jpeg,png,jpg,pdf|max:2048',
        ]);

        $user = Auth::user();

        if ($this->photographerRequestRepository->hasPendingRequest($user->id)) {
            return redirect()->back()->with('error', 'Anda sudah memiliki permintaan peninjauan yang sedang diproses.');
        }

        $ktpPath  = $request->file('ktp')->store('private/documents', 'local');
        $npwpPath = $request->file('npwp')->store('private/documents', 'local');

        $this->photographerRequestRepository->create([
            'user_id'   => $user->id,
            'ktp_path'  => $ktpPath,
            'npwp_path' => $npwpPath,
            'status'    => 'pending',
        ]);

        return redirect()->back()->with('success', 'Pengajuan fotografer berhasil dikirim. Menunggu verifikasi admin.');
    }

    /**
     * Show map showing all photographer/videographer locations
     */
    public function showMap(Request $request)
    {
        $photographers = \App\Models\User::whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->whereHas('role', function ($q) {
                $q->where('slug', 'photographer');
            })
            ->get();

        $photographersData = $photographers->map(function ($p) {
            return [
                'id' => $p->id,
                'name' => $p->name,
                'bio' => $p->bio ?? 'Tidak ada deskripsi bio.',
                'profile_photo_url' => $p->profile_photo_url,
                'latitude' => (float) $p->latitude,
                'longitude' => (float) $p->longitude,
                'explore_url' => route('explore', ['q' => $p->name]),
            ];
        });

        return view('photographer.map', ['photographers' => $photographersData]);
    }

    /**
     * Toggle follow on a user (AJAX).
     */
    public function followUser(Request $request, int $id)
    {
        if (!Auth::check()) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        $currentUser = Auth::user();
        if ($currentUser->id === $id) {
            return response()->json(['error' => 'Cannot follow yourself'], 400);
        }

        $targetUser = \App\Models\User::find($id);
        if (!$targetUser) {
            return response()->json(['error' => 'User not found'], 404);
        }

        $isFollowing = $currentUser->following()->where('user_id', $id)->exists();

        if ($isFollowing) {
            $currentUser->following()->detach($id);
            $following = false;
        } else {
            $currentUser->following()->attach($id);
            $following = true;

            // Trigger notification
            $targetUser->notify(new SystemNotification(
                'Pengikut Baru',
                $currentUser->name . ' mulai mengikuti Anda.',
                route('profile', $currentUser->username ?? ''),
                'follow'
            ));
        }

        return response()->json([
            'success'   => true,
            'following' => $following,
            'followers_count' => $targetUser->followers()->count(),
        ]);
    }
}
