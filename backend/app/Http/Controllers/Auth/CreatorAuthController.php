<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class CreatorAuthController extends Controller
{
    use AuthResponder;

    /**
     * Login creator.
     */
    public function login(Request $request)
    {
        $loginField = filter_var($request->email, FILTER_VALIDATE_EMAIL) ? 'email' : 'username';
        $credentials = [
            $loginField => $request->email,
            'password' => $request->password
        ];

        if (! $token = Auth::guard('api')->attempt($credentials)) {
            return response()->json(['success' => false, 'message' => 'Username/Email atau password salah.'], 401);
        }

        $user = Auth::guard('api')->user();

        // Validasi role spesifik untuk creator
        if ($user->role !== 'creator' && $user->role !== 'admin') {
            Auth::guard('api')->logout();
            return response()->json(['success' => false, 'message' => 'Akun Anda tidak memiliki akses sebagai Creator.'], 403);
        }

        return $this->respondWithToken($token);
    }

    /**
     * Logout creator.
     */
    public function logout(Request $request)
    {
        return $this->handleLogout($request);
    }

    /**
     * Refresh token creator.
     */
    public function refresh(Request $request)
    {
        return $this->handleRefresh($request);
    }
}
