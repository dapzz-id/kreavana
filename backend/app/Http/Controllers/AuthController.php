<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthController extends Controller
{

    public function register(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:100',
            'username' => 'required|string|max:50|unique:users',
            'email' => 'required|string|email|max:150|unique:users',
            'password' => 'required|string|min:6',
        ]);

        $user = User::create([
            'name' => $request->name,
            'username' => $request->username,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role' => 'user',
            'selected_pihak' => 'kreator',
            'is_creator_approved' => 0,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Registrasi berhasil',
            'data' => $user
        ]);
    }

    public function login(Request $request)
    {
        $credentials = $request->only('email', 'password');
        
        // Cek login via email atau username
        $loginField = filter_var($request->email, FILTER_VALIDATE_EMAIL) ? 'email' : 'username';
        $credentials = [
            $loginField => $request->email,
            'password' => $request->password
        ];

        if (! $token = Auth::guard('api')->attempt($credentials)) {
            return response()->json(['success' => false, 'message' => 'Username/Email atau password salah.'], 401);
        }

        return $this->respondWithToken($token);
    }

    public function me()
    {
        return response()->json([
            'success' => true,
            'data' => [
                'user' => Auth::guard('api')->user()
            ]
        ]);
    }

    public function logout(Request $request)
    {
        $sessionToken = $request->input('session_token');
        if ($sessionToken) {
            \App\Models\UserSession::where('session_token', $sessionToken)->delete();
        }
        
        Auth::guard('api')->logout();

        return response()->json(['success' => true, 'message' => 'Successfully logged out']);
    }

    public function refresh(Request $request)
    {
        $sessionToken = $request->input('session_token');
        $refreshToken = $request->input('refresh_token');

        if (!$sessionToken || !$refreshToken) {
            return response()->json([
                'success' => false,
                'message' => 'Sesi tidak valid.'
            ], 401);
        }

        $session = \App\Models\UserSession::where('session_token', $sessionToken)
            ->where('refresh_token', $refreshToken)
            ->first();

        if (!$session || $session->expires_at < now()) {
            if ($session) $session->delete();
            return response()->json([
                'success' => false,
                'message' => 'Sesi telah habis, silakan login kembali.'
            ], 401);
        }

        $user = $session->user;
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'User tidak ditemukan.'
            ], 401);
        }

        // Generate new JWT access token
        $token = Auth::guard('api')->login($user);

        // Rotate refresh token
        $newRefreshToken = Str::random(60);
        $session->update([
            'refresh_token' => $newRefreshToken
        ]);

        return $this->respondWithToken($token, $session->session_token, $newRefreshToken);
    }

    protected function respondWithToken($token, $sessionToken = null, $refreshToken = null)
    {
        $user = Auth::guard('api')->user();
        $user->id = (int)$user->id;
        $user->is_creator_approved = (int)$user->is_creator_approved;

        if (!$sessionToken || !$refreshToken) {
            $sessionToken = Str::random(60);
            $refreshToken = Str::random(60);

            // Create new session
            \App\Models\UserSession::create([
                'user_id' => $user->id,
                'session_token' => $sessionToken,
                'refresh_token' => $refreshToken,
                'expires_at' => now()->addDays(7),
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => 'Login berhasil.',
            'data' => [
                'token' => $token, // Backward compatibility with old api
                'access_token' => $token,
                'refresh_token' => $refreshToken,
                'session_token' => $sessionToken,
                'token_type' => 'bearer',
                'expires_in' => Auth::guard('api')->factory()->getTTL() * 60,
                'user' => $user
            ]
        ]);
    }
}
