<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\KycController;
use App\Http\Controllers\SessionController;
use App\Http\Controllers\DeviceController;
use App\Http\Controllers\WellKnownController;

/*
|--------------------------------------------------------------------------
| Universal Identity & Access Management (IAM) API Routes
|--------------------------------------------------------------------------
*/

// OpenID Discovery & JWKS
Route::get('.well-known/openid-configuration', [WellKnownController::class, 'openidConfiguration']);
Route::get('.well-known/jwks.json', [WellKnownController::class, 'jwks']);

// Health check
Route::get('health', function () {
    return response()->json([
        'status' => true,
        'service' => 'universal_identity_api',
        'timestamp' => now()->toIso8601String(),
    ]);
});

// V1 API Endpoints
Route::prefix('v1')->middleware(['client.app'])->group(function () {

    // Public Auth
    Route::prefix('auth')->group(function () {
        Route::post('register', [AuthController::class, 'register']);
        Route::post('login', [AuthController::class, 'login']);
        Route::post('refresh', [AuthController::class, 'refresh']);
        Route::post('social', [AuthController::class, 'socialLogin']);
    });

    // Authenticated Endpoints
    Route::middleware(['auth.jwt'])->group(function () {

        // Session & Auth
        Route::prefix('auth')->group(function () {
            Route::get('me', [AuthController::class, 'me']);
            Route::post('logout', [AuthController::class, 'logout']);
            Route::post('logout-all', [AuthController::class, 'logoutAllDevices']);
        });

        // Universal Profile
        Route::prefix('profile')->group(function () {
            Route::put('/', [ProfileController::class, 'updateProfile']);
            Route::post('change-password', [ProfileController::class, 'changePassword']);
            Route::get('addresses', [ProfileController::class, 'listAddresses']);
            Route::post('addresses', [ProfileController::class, 'addAddress']);
        });

        // Universal KYC
        Route::prefix('kyc')->group(function () {
            Route::post('submit', [KycController::class, 'submit']);
            Route::get('status', [KycController::class, 'getStatus']);
        });

        // Multi-App & Multi-Device Sessions
        Route::prefix('sessions')->group(function () {
            Route::get('/', [SessionController::class, 'listSessions']);
            Route::delete('{id}', [SessionController::class, 'revokeSession']);
        });

        // Device Registry
        Route::prefix('devices')->group(function () {
            Route::post('/', [DeviceController::class, 'registerOrUpdate']);
            Route::get('/', [DeviceController::class, 'listDevices']);
            Route::delete('{deviceId}', [DeviceController::class, 'unregister']);
        });
    });
});
