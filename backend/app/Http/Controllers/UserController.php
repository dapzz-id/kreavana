<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\User;

class UserController extends Controller
{
    public function search(Request $request)
    {
        $query = $request->query('q');
        if (empty($query)) {
            return response()->json([]);
        }

        // Use the authenticated user ID
        $currentUserId = $request->user()->id;

        $users = User::where('id', '!=', $currentUserId)
            ->where(function($q) use ($query) {
                $q->where('name', 'like', '%' . $query . '%')
                  ->orWhere('email', 'like', '%' . $query . '%');
            })
            ->limit(10)
            ->get();

        return response()->json($users);
    }
}
