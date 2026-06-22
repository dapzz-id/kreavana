<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

use Illuminate\Support\Facades\Auth;
use App\Models\User;
use App\Models\CreatorApplication;

class ProfileController extends Controller
{
    public function getProfile()
    {
        $user = Auth::guard('api')->user();
        return response()->json([
            'success' => true,
            'data' => $user
        ]);
    }

    public function updateProfile(Request $request)
    {
        $user = Auth::guard('api')->user();

        // Validasi opsional
        $request->validate([
            'name' => 'sometimes|string|max:100',
            'phone' => 'nullable|string|max:20',
            'selected_pihak' => 'sometimes|string|max:50',
            // avatar ditangani terpisah atau via base64/url
        ]);

        if ($request->has('name')) $user->name = $request->name;
        if ($request->has('phone')) $user->phone = $request->phone;
        if ($request->has('selected_pihak')) $user->selected_pihak = $request->selected_pihak;
        if ($request->has('avatar_url')) $user->avatar_url = $request->avatar_url;

        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Profil berhasil diperbarui.',
            'data' => $user
        ]);
    }

    public function applyCreator(Request $request)
    {
        $user = Auth::guard('api')->user();

        $request->validate([
            'pihak_category' => 'required|string',
            'skill_description' => 'required|string',
            'portfolio_link' => 'nullable|url',
            'experience' => 'nullable|string',
        ]);

        // Cek apakah sudah ada aplikasi pending
        $existing = CreatorApplication::where('user_id', $user->id)
            ->where('pihak_category', $request->pihak_category)
            ->where('status', 'pending')
            ->first();

        if ($existing) {
            return response()->json([
                'success' => false,
                'message' => 'Anda sudah memiliki pengajuan yang sedang diproses untuk kategori ini.'
            ], 400);
        }

        CreatorApplication::create([
            'user_id' => $user->id,
            'pihak_category' => $request->pihak_category,
            'skill_description' => $request->skill_description,
            'portfolio_link' => $request->portfolio_link,
            'experience' => $request->experience,
            'status' => 'pending'
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Pengajuan kreator berhasil dikirim dan sedang menunggu persetujuan admin.'
        ]);
    }
}
