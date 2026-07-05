<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Http\Requests\CallSignalRequest;
use App\Events\CallSignaling;
use App\Models\User;
use App\Traits\ApiResponse;
use Illuminate\Support\Facades\Log;

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

            $accessToken = app(KreavanaNotificationController::class)->getGoogleAccessToken();

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
