<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected function getAuthHeaders(\App\Models\User $user)
    {
        $token = \Tymon\JWTAuth\Facades\JWTAuth::fromUser($user);
        $payload = \Tymon\JWTAuth\Facades\JWTAuth::setToken($token)->getPayload();
        $jti = $payload->get('jti');
        if ($jti) {
            \App\Services\JtiService::store($jti, 3600);
        }
        return ['Authorization' => "Bearer $token"];
    }

    protected function actingAsApi(\App\Models\User $user)
    {
        $headers = $this->getAuthHeaders($user);
        return $this->withHeaders($headers);
    }
}
