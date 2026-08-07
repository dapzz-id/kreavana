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
        $query = $request->query('q');
        if (empty($query)) {
            return $this->successResponse('Hasil pencarian', []);
        }

        $currentUserId = $request->user()->id;

        $users = User::select('id', 'name', 'username', 'avatar_url', 'phone', 'role', 'selected_sub_role')
            ->where('id', '!=', $currentUserId)
            ->where(function($q) use ($query) {
                $q->where('name', 'like', '%' . $query . '%')
                  ->orWhere('username', 'like', '%' . $query . '%');
            })
            ->limit(20)
            ->get();

        return $this->successResponse('Hasil pencarian pengguna', $users->toArray());
    }

    /**
     * Daftar kontak untuk memulai obrolan/panggilan: admin, kreator, dan klien.
     */
    public function contacts(Request $request)
    {
        $currentUserId = $request->user()->id;

        $users = User::where('id', '!=', $currentUserId)
            ->whereNotNull('username')
            ->orderByRaw("FIELD(role, 'admin', 'creator', 'user')")
            ->orderBy('name')
            ->limit(50)
            ->get(['id', 'name', 'username', 'email', 'phone', 'avatar_url', 'role', 'selected_sub_role']);

        return $this->successResponse('Daftar kontak berhasil diambil', $users->toArray());
    }
}
