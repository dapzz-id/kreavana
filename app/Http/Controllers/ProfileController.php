<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class ProfileController extends Controller
{
    /**
     * Show user profile overview
     */
    public function index($username = null)
    {
        $currentUser = Auth::user();
        
        if ($username) {
            $user = \App\Models\User::where('username', $username)->first();
            if (!$user) {
                // Try finding by ID as fallback if numeric
                if (is_numeric($username)) {
                    $user = \App\Models\User::find($username);
                }
                if (!$user) {
                    abort(404, 'User tidak ditemukan.');
                }
            }
        } else {
            if (!$currentUser) {
                return redirect()->route('login');
            }
            $user = $currentUser;
        }

        // Purchased photos
        $purchasedPhotos = \App\Models\Photo::whereHas('purchases', fn ($q) =>
            $q->where('user_id', $user->id)->where('payment_status', 'completed')
        )->latest()->get();

        // Uploaded (if photographer)
        $uploadedPhotos = $user->isPhotographer()
            ? $user->photos()->latest()->get()
            : collect();

        // Saved photos
        $savedPhotos = \App\Models\Photo::whereHas('savedBy', fn ($q) =>
            $q->where('user_id', $user->id)
        )->latest()->get();

        // Stats
        $stats = [
            'posts'     => $uploadedPhotos->count(),
            'followers' => $user->followers()->count(),
            'following' => $user->following()->count(),
            'purchased' => $purchasedPhotos->count(),
        ];

        // Is the current user following this profile?
        $isFollowing = false;
        if ($currentUser && $currentUser->id !== $user->id) {
            $isFollowing = $currentUser->following()->where('user_id', $user->id)->exists();
        }

        return view('profile.index', compact(
            'user',
            'purchasedPhotos',
            'uploadedPhotos',
            'savedPhotos',
            'stats',
            'isFollowing'
        ));
    }

    /**
     * Show the profile edit form
     */
    public function show()
    {
        $user = Auth::user();
        $photographerRequest = \App\Models\PhotographerRequest::where('user_id', $user->id)->latest()->first();
        return view('profile.edit', compact('user', 'photographerRequest'));
    }

    /**
     * Update profile information
     */
    public function update(Request $request)
    {
        $user = Auth::user();

        $request->validate([
            'name'      => 'required|string|max:100',
            'username'  => ['nullable', 'string', 'max:30', 'alpha_dash', Rule::unique('users', 'username')->ignore($user->id)],
            'bio'       => 'nullable|string|max:500',
            'website'   => 'nullable|url|max:255',
            'email'     => ['required', 'email', Rule::unique('users', 'email')->ignore($user->id)],
            'latitude'  => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
        ]);

        $user->name      = $request->name;
        $user->username  = $request->username;
        $user->bio       = $request->bio;
        $user->website   = $request->website;
        $user->email     = $request->email;
        $user->latitude  = $request->latitude;
        $user->longitude = $request->longitude;
        $user->save();

        return back()->with('success', 'Profil berhasil diperbarui.');
    }

    /**
     * Update profile photo
     */
    public function updatePhoto(Request $request)
    {
        $request->validate([
            'photo' => 'required|image|mimes:jpg,jpeg,png,webp|max:5120', // 5MB
        ]);

        $user = Auth::user();

        // Delete old photo
        if ($user->profile_photo_path && Storage::disk('public')->exists($user->profile_photo_path)) {
            Storage::disk('public')->delete($user->profile_photo_path);
        }

        $path = $request->file('photo')->store("profiles/{$user->id}", 'public');
        $user->profile_photo_path = $path;
        $user->save();

        return back()->with('success', 'Foto profil berhasil diperbarui.');
    }

    /**
     * Update password
     */
    public function updatePassword(Request $request)
    {
        $request->validate([
            'current_password'      => 'required|string',
            'password'              => 'required|string|min:8|confirmed',
            'password_confirmation' => 'required',
        ]);

        $user = Auth::user();

        if (!Hash::check($request->current_password, $user->password)) {
            return back()->withErrors(['current_password' => 'Kata sandi saat ini tidak sesuai.']);
        }

        $user->password = Hash::make($request->password);
        $user->save();

        return back()->with('success', 'Kata sandi berhasil diubah.');
    }

    /**
     * Store face embedding data for RoboYu AI scan
     */
    public function storeFaceEmbedding(Request $request)
    {
        $request->validate([
            'selfie' => 'required|image|mimes:jpg,jpeg,png|max:10240',
        ]);

        $user = Auth::user();

        // Store the selfie for the AI pipeline
        $path = $request->file('selfie')->store("face_scans/{$user->id}", 'public');

        // In production: call your AI service (Python/Flask face recognition endpoint)
        // For now, store path as embedding placeholder
        $user->face_embeddings = [
            'selfie_path'   => $path,
            'uploaded_at'   => now()->toISOString(),
            'status'        => 'pending', // AI pipeline processes this async
        ];
        $user->save();

        return response()->json([
            'success'    => true,
            'message'    => 'Selfie diterima. Sistem AI sedang memproses wajah Anda.',
            'selfie_url' => Storage::url($path),
        ]);
    }
}
