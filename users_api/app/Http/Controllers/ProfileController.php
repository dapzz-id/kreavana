<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\UserAddress;
use App\Models\UserCredential;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Tymon\JWTAuth\Facades\JWTAuth;

class ProfileController
{
    public function updateProfile(Request $request)
    {
        $user = JWTAuth::parseToken()->authenticate();

        $validator = Validator::make($request->all(), [
            'full_name' => 'sometimes|string|max:255',
            'display_name' => 'sometimes|string|max:255',
            'avatar_url' => 'sometimes|string|url|max:500',
            'phone' => 'sometimes|nullable|string|max:30|unique:users,phone,' . $user->id,
            'username' => 'sometimes|string|min:3|max:50|unique:users,username,' . $user->id,
            'email' => 'sometimes|email|max:150|unique:users,email,' . $user->id,
            'date_of_birth' => 'sometimes|nullable|date',
            'gender' => 'sometimes|nullable|in:male,female,other',
            'locale' => 'sometimes|string|max:10',
            'timezone' => 'sometimes|string|max:50',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Validasi profil gagal.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $user->update($request->only([
            'username',
            'email',
            'full_name',
            'display_name',
            'avatar_url',
            'phone',
            'date_of_birth',
            'gender',
            'locale',
            'timezone',
        ]));

        return response()->json([
            'status' => true,
            'message' => 'Profil universal berhasil diperbarui.',
            'data' => $user->fresh(),
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
