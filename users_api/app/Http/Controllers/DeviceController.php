<?php

namespace App\Http\Controllers;

use App\Models\UserDevice;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Tymon\JWTAuth\Facades\JWTAuth;

class DeviceController
{
    /**
     * Register or update a user device (e.g. FCM push token, E2EE public key).
     */
    public function registerOrUpdate(Request $request)
    {
        $userId = JWTAuth::parseToken()->getPayload()->get('sub');

        $validator = Validator::make($request->all(), [
            'device_id' => 'required|string',
            'device_name' => 'nullable|string|max:100',
            'platform' => 'nullable|string|in:ios,android,web,windows,macos,linux',
            'fcm_token' => 'nullable|string',
            'public_key' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Data perangkat tidak valid.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $device = UserDevice::updateOrCreate(
            [
                'user_id' => $userId,
                'device_id' => $request->device_id,
            ],
            [
                'device_name' => $request->device_name,
                'platform' => $request->platform ?? 'web',
                'fcm_token' => $request->fcm_token,
                'public_key' => $request->public_key,
                'last_active_at' => now(),
            ]
        );

        return response()->json([
            'status' => true,
            'message' => 'Perangkat berhasil didaftarkan.',
            'data' => $device,
        ]);
    }

    /**
     * List all registered devices for user.
     */
    public function listDevices(Request $request)
    {
        $userId = JWTAuth::parseToken()->getPayload()->get('sub');

        $devices = UserDevice::where('user_id', $userId)
            ->orderByDesc('last_active_at')
            ->get();

        return response()->json([
            'status' => true,
            'data' => $devices,
        ]);
    }

    /**
     * Remove / unregister a device.
     */
    public function unregister(Request $request, string $deviceId)
    {
        $userId = JWTAuth::parseToken()->getPayload()->get('sub');

        UserDevice::where('user_id', $userId)
            ->where('device_id', $deviceId)
            ->delete();

        return response()->json([
            'status' => true,
            'message' => 'Perangkat berhasil dihapus.',
        ]);
    }
}
