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

        $users = User::select('id', 'name', 'username', 'avatar_url')
            ->where('id', '!=', $currentUserId)
            ->where(function($q) use ($query) {
                $q->where('name', 'like', '%' . $query . '%')
                  ->orWhere('username', 'like', '%' . $query . '%');
            })
            ->limit(10)
            ->get();

        return $this->successResponse('Hasil pencarian pengguna', $users->toArray());
    }
}
