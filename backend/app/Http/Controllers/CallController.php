<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Events\CallSignaling;
use App\Models\User;
use Illuminate\Support\Facades\Log;

class CallController extends Controller
{
    /**
     * Send WebRTC Signaling data to the receiver via Laravel Reverb
     */
    public function signal(Request $request)
    {
        $request->validate([
            'receiver_id' => 'required|integer',
            'call_id' => 'required|string',
            'type' => 'required|string|in:offer,answer,candidate,reject,end,ringing,connected',
            'data' => 'nullable|array'
        ]);

        $caller = $request->user();
        $receiverId = $request->receiver_id;

        Log::info("WebRTC Signal ({$request->type}) from User {$caller->id} to User {$receiverId}");

        $data = $request->data ?? [];
        if ($request->type === 'offer') {
            $data['callerName'] = $caller->name;
            $data['callerAvatar'] = $caller->avatar_url ?? '';
        }

        // Broadcast signal via Pusher / Reverb
        broadcast(new CallSignaling(
            $receiverId,
            $caller->id,
            $request->call_id,
            $request->type,
            $data
        ));

        // If it's an offer, we might want to also trigger an FCM VoIP Push Notification 
        // to wake up the receiver's phone if it's in the background.
        if ($request->type === 'offer') {
            $this->sendCallPushNotification($receiverId, $caller, $request->call_id, $request->data);
        }

        return response()->json(['success' => true]);
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
                    // Android-specific settings for high priority CallKit
                    'android' => [
                        'priority' => 'high',
                        'ttl' => '0s', // deliver immediately or not at all
                    ],
                    // APNs for iOS VoIP
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
                        'type' => 'call', // custom type intercepted by flutter_callkit_incoming
                        'call_id' => $callId,
                        'caller_id' => (string) $caller->id,
                        'caller_name' => $caller->name,
                        // 'caller_avatar' => $caller->avatar_url, // if available
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
