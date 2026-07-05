<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use App\Models\User;
use App\Models\AuthLog;

class AuthController extends Controller
{
    use AuthResponder;

    /**
     * Register user baru (public).
     */
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
            'is_creator_approved' => 0,
        ]);

        return response()->json(['status' => true], 201);
    }

    /**
     * Login user.
     */
    public function login(Request $request)
    {
        return $this->attemptLogin($request);
    }

    public function userLogin(Request $request)
    {
        return $this->attemptLogin($request, 'user');
    }

    public function creatorLogin(Request $request)
    {
        return $this->attemptLogin($request, 'creator');
    }

    public function adminLogin(Request $request)
    {
        return $this->attemptLogin($request, 'admin');
    }

    private function attemptLogin(Request $request, ?string $requiredRole = null)
    {
        $request->validate([
            'email' => 'required|string',
            'password' => 'required|string',
        ]);

        $loginField = filter_var($request->email, FILTER_VALIDATE_EMAIL) ? 'email' : 'username';
        $credentials = [
            $loginField => $request->email,
            'password' => $request->password
        ];

        if (! $token = Auth::guard('api')->attempt($credentials)) {
            AuthLog::create([
                'user_id' => null,
                'action' => 'login_failed',
                'ip_address' => $request->ip(),
                'user_agent' => substr((string) $request->userAgent(), 0, 255)
            ]);
            return $this->genericUnauthorized();
        }

        $user = Auth::guard('api')->user();
        if ($requiredRole && $user->role !== $requiredRole) {
            Auth::guard('api')->logout();
            AuthLog::create([
                'user_id' => $user->id,
                'action' => 'login_forbidden',
                'ip_address' => $request->ip(),
                'user_agent' => substr((string) $request->userAgent(), 0, 255)
            ]);

            return response()->json(['status' => false, 'message' => 'Forbidden'], 403);
        }

        AuthLog::create([
            'user_id' => $user->id,
            'action' => 'login',
            'ip_address' => $request->ip(),
            'user_agent' => substr((string) $request->userAgent(), 0, 255)
        ]);

        return $this->respondWithToken($token, $user);
    }

    /**
     * Logout user.
     */
    public function logout(Request $request)
    {
        return $this->handleLogout($request);
    }

    /**
     * Refresh token user.
     */
    public function refresh(Request $request)
    {
        return $this->handleRefresh($request);
    }

    /**
     * Get current user data.
     */
    public function me()
    {
        $user = Auth::guard('api')->user();

        return response()->json([
            'status' => true,
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'uid' => $user->id,
                    'name' => $user->name,
                    'username' => $user->username,
                    'email' => $user->email,
                    'role' => $user->role,
                    'sub_role' => $user->sub_role,
                    'is_creator_approved' => (bool) $user->is_creator_approved,
                    'permissions' => config('permissions.' . $user->role, []),
                ],
            ]
        ]);
    }
}
