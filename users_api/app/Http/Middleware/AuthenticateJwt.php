<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Tymon\JWTAuth\Facades\JWTAuth;
use Tymon\JWTAuth\Exceptions\TokenExpiredException;
use Tymon\JWTAuth\Exceptions\TokenInvalidException;
use Tymon\JWTAuth\Exceptions\JWTException;

class AuthenticateJwt
{
    /**
     * Handle incoming request authenticated with JWT.
     */
    public function handle(Request $request, Closure $next): Response
    {
        try {
            $user = JWTAuth::parseToken()->authenticate();

            if (!$user) {
                return response()->json([
                    'status' => false,
                    'message' => 'User not found.',
                ], 404);
            }

            if ($user->is_suspended || !$user->is_active) {
                return response()->json([
                    'status' => false,
                    'message' => 'Akun Anda dinonaktifkan atau ditangguhkan.',
                ], 403);
            }
        } catch (TokenExpiredException $e) {
            return response()->json([
                'status' => false,
                'message' => 'Token kedaluwarsa. Silakan refresh token Anda.',
                'error_code' => 'TOKEN_EXPIRED',
            ], 401);
        } catch (TokenInvalidException $e) {
            return response()->json([
                'status' => false,
                'message' => 'Token tidak valid.',
                'error_code' => 'TOKEN_INVALID',
            ], 401);
        } catch (JWTException $e) {
            return response()->json([
                'status' => false,
                'message' => 'Token otentikasi tidak ditemukan.',
                'error_code' => 'TOKEN_MISSING',
            ], 401);
        }

        return $next($request);
    }
}
