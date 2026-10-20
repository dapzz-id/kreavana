<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class WellKnownController
{
    /**
     * OpenID Connect Discovery endpoint.
     */
    public function openidConfiguration()
    {
        $baseUrl = url('/');

        return response()->json([
            'issuer' => $baseUrl,
            'authorization_endpoint' => $baseUrl . '/api/v1/auth/login',
            'token_endpoint' => $baseUrl . '/api/v1/auth/refresh',
            'userinfo_endpoint' => $baseUrl . '/api/v1/auth/me',
            'jwks_uri' => $baseUrl . '/.well-known/jwks.json',
            'response_types_supported' => ['token', 'id_token'],
            'subject_types_supported' => ['public'],
            'id_token_signing_alg_values_supported' => ['HS256', 'RS256'],
            'scopes_supported' => ['openid', 'profile', 'email', 'phone', 'kyc'],
            'claims_supported' => [
                'sub',
                'iss',
                'iat',
                'exp',
                'username',
                'email',
                'full_name',
                'avatar_url',
                'is_kyc_verified',
                'locale',
            ],
        ]);
    }

    /**
     * JSON Web Key Set (JWKS) metadata endpoint.
     */
    public function jwks()
    {
        return response()->json([
            'keys' => [
                [
                    'kty' => 'oct',
                    'alg' => config('jwt.algo', 'HS256'),
                    'use' => 'sig',
                    'kid' => 'universal-identity-key-v1',
                ],
            ],
        ]);
    }
}
