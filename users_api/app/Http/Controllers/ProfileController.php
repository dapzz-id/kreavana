<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\UserAddress;
use App\Models\UserCredential;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Tymon\JWTAuth\Facades\JWTAuth;

class ProfileController
{
    public function updateProfile(Request $request)
    {
        $user = JWTAuth::parseToken()->authenticate();

        return $this->validateAndPersistProfile($request, $user, wrapInUserKey: false);
    }

    /**
     * Internal S2S profile synchronization endpoint called by ecosystem backends (e.g. Kreavana backend).
     */
    public function internalUpdateProfile(Request $request)
    {
        $userId = trim((string) $request->input('user_id', ''));
        $currentEmail = strtolower(trim((string) $request->input('current_email', '')));
        $currentUsername = strtolower(trim((string) $request->input('current_username', '')));

        if ($userId === '' && $currentEmail === '' && $currentUsername === '') {
            return response()->json([
                'status' => false,
                'message' => 'Parameter identitas pengguna (user_id, current_email, atau current_username) diperlukan.',
            ], 422);
        }

        $user = null;
        if ($userId !== '') {
            $user = User::find($userId);
        }
        if (!$user && $currentEmail !== '') {
            $user = User::whereRaw('LOWER(email) = ?', [$currentEmail])->first();
        }
        if (!$user && $currentUsername !== '') {
            $user = User::whereRaw('LOWER(username) = ?', [$currentUsername])->first();
        }

        if (!$user) {
            return response()->json([
                'status' => false,
                'message' => 'Akun identitas universal tidak ditemukan pada layanan Users API.',
            ], 404);
        }

        return $this->validateAndPersistProfile($request, $user, wrapInUserKey: true);
    }

    /**
     * Normalize, validate, and persist profile updates for the resolved universal user.
     */
    private function validateAndPersistProfile(Request $request, User $user, bool $wrapInUserKey)
    {
        $fields = [
            'full_name',
            'display_name',
            'avatar_url',
            'phone',
            'username',
            'email',
            'date_of_birth',
            'gender',
            'locale',
            'timezone',
        ];

        $input = [];
        foreach ($fields as $field) {
            if (!$request->exists($field)) {
                continue;
            }
            $value = $request->input($field);
            if ($field === 'username' || $field === 'email') {
                $trimmed = strtolower(trim((string) $value));
                if ($trimmed !== '') {
                    $input[$field] = $trimmed;
                }
            } elseif ($field === 'phone') {
                $trimmed = trim((string) ($value ?? ''));
                $input[$field] = $trimmed !== '' ? $trimmed : null;
            } elseif ($field === 'full_name' || $field === 'display_name') {
                $trimmed = trim((string) ($value ?? ''));
                if ($trimmed !== '') {
                    $input[$field] = $trimmed;
                }
            } else {
                $input[$field] = $value;
            }
        }

        $validator = Validator::make($input, [
            'full_name' => 'sometimes|string|min:2|max:255',
            'display_name' => 'sometimes|nullable|string|max:255',
            'avatar_url' => 'sometimes|nullable|string|max:500',
            'phone' => ['sometimes', 'nullable', 'string', 'max:35', Rule::unique('users', 'phone')->ignore($user->id)],
            'username' => ['sometimes', 'string', 'min:3', 'max:50', 'regex:/^[a-zA-Z0-9_.-]+$/', Rule::unique('users', 'username')->ignore($user->id)],
            'email' => ['sometimes', 'email', 'max:150', Rule::unique('users', 'email')->ignore($user->id)],
            'date_of_birth' => 'sometimes|nullable|date',
            'gender' => 'sometimes|nullable|in:male,female,other',
            'locale' => 'sometimes|string|max:10',
            'timezone' => 'sometimes|string|max:50',
        ], [
            'full_name.min' => 'Nama lengkap minimal 2 karakter.',
            'full_name.max' => 'Nama lengkap maksimal 255 karakter.',
            'phone.unique' => 'Nomor telepon ini sudah digunakan oleh akun lain.',
            'phone.max' => 'Nomor telepon maksimal 35 karakter.',
            'username.min' => 'Username minimal 3 karakter.',
            'username.max' => 'Username maksimal 50 karakter.',
            'username.regex' => 'Username hanya boleh berisi huruf, angka, titik, strip, dan underscore.',
            'username.unique' => 'Username ini sudah digunakan oleh akun lain.',
            'email.email' => 'Format alamat email tidak valid.',
            'email.unique' => 'Alamat email ini sudah terdaftar pada akun lain.',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => $validator->errors()->first(),
                'errors' => $validator->errors(),
            ], 422);
        }

        $validated = $validator->validated();
        if (!empty($validated)) {
            $user->update($validated);
        }

        $freshUser = $user->fresh();
        $data = $wrapInUserKey
            ? [
                'user' => [
                    'id' => $freshUser->id,
                    'username' => $freshUser->username,
                    'email' => $freshUser->email,
                    'phone' => $freshUser->phone,
                    'full_name' => $freshUser->full_name,
                    'display_name' => $freshUser->display_name,
                    'avatar_url' => $freshUser->avatar_url,
                ],
            ]
            : $freshUser;

        return response()->json([
            'status' => true,
            'message' => 'Profil universal berhasil diperbarui.',
            'data' => $data,
        ]);
    }

    public function changePassword(Request $request)
    {
        $user = JWTAuth::parseToken()->authenticate();

        $validator = Validator::make($request->all(), [
            'current_password' => 'required|string',
            'new_password' => 'required|string|min:8|different:current_password',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Validasi ganti kata sandi gagal.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $credential = $user->credential;
        if (!$credential || !Hash::check($request->current_password, $credential->password_hash)) {
            return response()->json([
                'status' => false,
                'message' => 'Kata sandi saat ini salah.',
            ], 400);
        }

        $credential->update([
            'password_hash' => Hash::make($request->new_password),
            'password_changed_at' => now(),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Kata sandi berhasil diperbarui di seluruh ekosistem.',
        ]);
    }

    public function listAddresses(Request $request)
    {
        $user = JWTAuth::parseToken()->authenticate();
        return response()->json([
            'status' => true,
            'data' => $user->addresses()->orderByDesc('is_default')->get(),
        ]);
    }

    public function addAddress(Request $request)
    {
        $user = JWTAuth::parseToken()->authenticate();

        $validator = Validator::make($request->all(), [
            'label' => 'required|string|max:50',
            'recipient_name' => 'required|string|max:100',
            'phone_number' => 'required|string|max:30',
            'street_address' => 'required|string',
            'city' => 'required|string|max:100',
            'state' => 'required|string|max:100',
            'postal_code' => 'required|string|max:20',
            'is_default' => 'nullable|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Data alamat tidak valid.',
                'errors' => $validator->errors(),
            ], 422);
        }

        if ($request->is_default) {
            $user->addresses()->update(['is_default' => false]);
        }

        $address = $user->addresses()->create($request->all());

        return response()->json([
            'status' => true,
            'message' => 'Alamat berhasil ditambahkan.',
            'data' => $address,
        ], 201);
    }
}
