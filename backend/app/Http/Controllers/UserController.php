<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Traits\ApiResponse;
use App\Models\User;

class UserController extends Controller
{
    use ApiResponse;

    public function search(Request $request)
    {
        $query = trim($request->query('q', ''));
        if (empty($query)) {
            return $this->successResponse('Hasil pencarian', []);
        }

        $currentUserId = $request->user()->id;

        // 1. Direct match (exact or LIKE)
        $users = User::select('id', 'name', 'username', 'email', 'avatar_url', 'phone', 'role', 'sub_role as selected_sub_role')
            ->where('id', '!=', $currentUserId)
            ->where(function($q) use ($query) {
                $q->where('name', 'like', '%' . $query . '%')
                  ->orWhere('username', 'like', '%' . $query . '%')
                  ->orWhere('email', 'like', '%' . $query . '%');
            })
            ->limit(20)
            ->get();

        if ($users->isNotEmpty()) {
            return $this->successResponse('Hasil pencarian pengguna', $users->toArray());
        }

        // 2. Fuzzy fallback: extract sub-words
        $cleanQuery = preg_replace('/[^a-zA-Z0-9]/', ' ', $query);
        $tokens = array_filter(explode(' ', $cleanQuery), fn($t) => strlen($t) >= 3 && !in_array($t, ['gmail', 'yahoo', 'hotmail', 'com', 'co', 'id']));

        if (!empty($tokens)) {
            $users = User::select('id', 'name', 'username', 'email', 'avatar_url', 'phone', 'role', 'sub_role as selected_sub_role')
                ->where('id', '!=', $currentUserId)
                ->where(function($q) use ($tokens) {
                    foreach ($tokens as $token) {
                        $q->orWhere('name', 'like', '%' . $token . '%')
                          ->orWhere('username', 'like', '%' . $token . '%')
                          ->orWhere('email', 'like', '%' . $token . '%');
                    }
                })
                ->limit(20)
                ->get();
        }

        return $this->successResponse('Hasil pencarian pengguna', $users->toArray());
    }

    /**
     * Daftar kontak untuk memulai obrolan/panggilan: admin, kreator, dan klien.
     */
    public function contacts(Request $request)
    {
        $currentUserId = $request->user()->id;

        $users = User::where('id', '!=', $currentUserId)
            ->orderByRaw("FIELD(role, 'admin', 'creator', 'user')")
            ->orderBy('name')
            ->limit(100)
            ->get(['id', 'name', 'username', 'email', 'phone', 'avatar_url', 'role', 'sub_role as selected_sub_role']);

        return $this->successResponse('Daftar kontak berhasil diambil', $users->toArray());
    }

    public function updateFcmToken(Request $request)
    {
        $request->validate([
            'fcm_token' => 'required|string',
            'device_id' => 'nullable|string',
        ]);

        $user = $request->user();
        
        // Backward compatibility: selalu update legacy token
        $user->fcm_token = $request->fcm_token;
        $user->save();

        if ($request->device_id) {
            \App\Models\UserDevice::where('user_id', $user->id)
                ->where('device_id', $request->device_id)
                ->update(['fcm_token' => $request->fcm_token]);
        }

        return $this->successResponse('FCM token berhasil diperbarui.');
    }

    public function registerDevice(Request $request)
    {
        $request->validate([
            'device_id' => 'required|string',
            'public_key' => 'required|string',
        ]);

        $user = $request->user();

        // Reactivate device or create a new one
        $device = \App\Models\UserDevice::updateOrCreate(
            [
                'user_id' => $user->id,
                'device_id' => $request->device_id,
            ],
            [
                'public_key' => $request->public_key,
                'is_active' => true,
                'revoked_at' => null,
            ]
        );

        return $this->successResponse('Device registered successfully', $device->toArray());
    }
}
