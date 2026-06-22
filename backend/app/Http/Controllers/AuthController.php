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

    public function logout()
    {
        Auth::guard('api')->logout();

        return response()->json(['success' => true, 'message' => 'Successfully logged out']);
    }

    public function refresh()
    {
        return $this->respondWithToken(Auth::guard('api')->refresh());
    }

    protected function respondWithToken($token)
    {
        $user = Auth::guard('api')->user();
        $user->id = (int)$user->id;
        $user->is_creator_approved = (int)$user->is_creator_approved;

        return response()->json([
            'success' => true,
            'message' => 'Login berhasil.',
            'data' => [
                'token' => $token, // Backward compatibility with old api
                'access_token' => $token,
                'refresh_token' => $token, // Use same token or implement proper refresh logic in frontend
                'session_token' => Str::random(60),
                'token_type' => 'bearer',
                'expires_in' => Auth::guard('api')->factory()->getTTL() * 60,
                'user' => $user
            ]
        ]);
    }
}
