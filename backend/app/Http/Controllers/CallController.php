<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Http\Requests\CallSignalRequest;
use App\Events\CallSignaling;
use App\Models\User;
use App\Traits\ApiResponse;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;

class CallController extends Controller
{
    use ApiResponse;

    /**
     * Send WebRTC Signaling data to the receiver via Laravel Reverb
     */
    public function signal(CallSignalRequest $request)
    {
        $caller = $request->user();
        $receiverId = $request->receiver_id;

        Log::info("WebRTC Signal ({$request->type}) from User {$caller->id} to User {$receiverId}");

        $data = $request->data ?? [];
        if ($request->type === 'offer') {
            $data['callerName'] = $caller->name;
            $data['callerAvatar'] = $caller->avatar_url ?? '';
            
            // Inject authoritative duration from backend
            $isVideo = isset($request->data['video']) && $request->data['video'] === true;
            $data['max_duration'] = $isVideo 
                ? $caller->max_video_call_duration_seconds 
                : $caller->max_voice_call_duration_seconds;
        }

        broadcast(new CallSignaling(
            $receiverId,
            $caller->id,
            $request->call_id,
            $request->type,
            $data
        ));

        if ($request->type === 'offer') {
            $this->sendCallPushNotification($receiverId, $caller, $request->call_id, $request->data);
        }

        return $this->successResponse('Signal berhasil dikirim');
    }

    /**
     * Get time-limited TURN credentials using HMAC-based REST API auth.
     * Uses Coturn `use-auth-secret` mechanism. Expiry 6 hours by default.
     */
    public function getTurnCredentials(Request $request)
    {
        $user = $request->user();
        $turnSecret = env('TURN_SECRET', 'kreavana_default_secret_change_in_prod');
        $turnHost = env('TURN_HOST', $request->getHost());
        $turnPort = (int) env('TURN_PORT', 3478);
        $ttlSeconds = (int) env('TURN_TOKEN_TTL', 21600); // 6 hours

        $expiry = time() + $ttlSeconds;
        $username = "{$expiry}:user_{$user->id}";

        if (!function_exists('hash_hmac')) {
            return $this->errorResponse('hash_hmac tidak tersedia di server PHP.', 500);
        }

        $hmac = hash_hmac('sha1', $username, $turnSecret, true);
        $password = base64_encode($hmac);

        $iceServers = [
            [
                'urls' => "stun:{$turnHost}:{$turnPort}",
            ],
            [
                'urls' => [
                    "turn:{$turnHost}:{$turnPort}",
                    "turn:{$turnHost}:{$turnPort}?transport=tcp",
                ],
                'username' => $username,
                'credential' => $password,
            ],
        ];

        // Cache for a bit less than TTL to avoid repeated generation
        Cache::put("turn:token:user_{$user->id}", [
            'username' => $username,
            'password' => $password,
        ], (int) ($ttlSeconds * 0.9));

        return $this->successResponse('TURN credentials berhasil diambil', [
            'ice_servers' => $iceServers,
            'username'    => $username,
            'password'    => $password,
            'ttl_seconds' => $ttlSeconds,
            'stun_host'   => "stun:{$turnHost}:{$turnPort}",
            'turn_host'   => "turn:{$turnHost}:{$turnPort}",
        ]);
    }

    /**
     * Optional: Send FCM Push Notification with high priority to trigger CallKit
     */
    private function sendCallPushNotification($receiverId, $caller, $callId, $data)
    {
        $receiver = User::find($receiverId);
        if (!$receiver || !$receiver->fcm_token) {
            return;
        }

        try {
            $projectId = env('FIREBASE_PROJECT_ID');
            if (!$projectId) return;

            $accessToken = app(\App\Services\FcmService::class)->getGoogleAccessToken();

            $payload = [
                'message' => [
                    'token' => $receiver->fcm_token,
                    'android' => [
                        'priority' => 'high',
                        'ttl' => '0s',
                    ],
                    'apns' => [
                        'headers' => [
                            'apns-priority' => '10',
                        ],
                        'payload' => [
                            'aps' => [
                                'content-available' => 1,
                            ]
                        ]
                    ],
                    'data' => [
                        'type' => 'call',
                        'call_id' => $callId,
                        'caller_id' => (string) $caller->id,
                        'caller_name' => $caller->name,
                    ]
                ]
            ];

            $ch = curl_init("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send");
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Authorization: Bearer ' . $accessToken,
                'Content-Type: application/json'
            ]);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            
            $response = curl_exec($ch);
            curl_close($ch);
            
            Log::info("FCM Call Push sent to User {$receiverId}");
            
        } catch (\Exception $e) {
            Log::error("Failed to send FCM Call Push: " . $e->getMessage());
        }
    }
}
