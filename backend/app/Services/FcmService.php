<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;

class FcmService extends BaseService
{
    /**
     * Get OAuth 2.0 Token using Service Account JSON.
     * Uses FIREBASE_CREDENTIALS path from .env.
     */
    public function getGoogleAccessToken(): ?string
    {
        try {
            $credentialsPath = env('FIREBASE_CREDENTIALS');
            
            if (!$credentialsPath || !file_exists(base_path($credentialsPath))) {
                Log::warning('FCM: Service account JSON not found.');
                return null;
            }

            $credentials = json_decode(file_get_contents(base_path($credentialsPath)), true);
            if (!$credentials || !isset($credentials['private_key'])) {
                Log::warning('FCM: Invalid Service account JSON.');
                return null;
            }

            $header = json_encode(['alg' => 'RS256', 'typ' => 'JWT']);
            $now = time();
            $payload = json_encode([
                'iss' => $credentials['client_email'],
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => 'https://oauth2.googleapis.com/token',
                'exp' => $now + 3600,
                'iat' => $now
            ]);

            $base64UrlHeader = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($header));
            $base64UrlPayload = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($payload));

            $signature = '';
            openssl_sign($base64UrlHeader . '.' . $base64UrlPayload, $signature, $credentials['private_key'], 'sha256');
            $base64UrlSignature = str_replace(['+', '/', '='], ['-', '_', ''], base64_encode($signature));

            $jwt = $base64UrlHeader . '.' . $base64UrlPayload . '.' . $base64UrlSignature;

            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, 'https://oauth2.googleapis.com/token');
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt
            ]));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);
            
            $response = curl_exec($ch);
            curl_close($ch);

            $data = json_decode($response, true);
            return $data['access_token'] ?? null;

        } catch (\Exception $e) {
            Log::error('FCM: Failed to get Google access token - ' . $e->getMessage());
            return null;
        }
    }

    /**
     * Send FCM Push Notification
     */
    public function sendPushNotification(string $fcmToken, string $title, string $body, array $data = []): bool
    {
        $projectId = env('FIREBASE_PROJECT_ID');
        if (!$projectId || !$fcmToken) {
            return false;
        }

        $accessToken = $this->getGoogleAccessToken();
        if (!$accessToken) {
            return false;
        }

        // Convert data values to strings per FCM requirements
        $stringData = [];
        foreach ($data as $k => $v) {
            $stringData[$k] = (string)$v;
        }

        $payload = [
            'message' => [
                'token' => $fcmToken,
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                ],
                'data' => $stringData,
                'android' => [
                    'priority' => 'high',
                ],
                'apns' => [
                    'payload' => [
                        'aps' => [
                            'sound' => 'default',
                            'badge' => 1
                        ]
                    ]
                ]
            ]
        ];

        try {
            $ch = curl_init("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send");
            curl_setopt($ch, CURLOPT_HTTPHEADER, [
                'Authorization: Bearer ' . $accessToken,
                'Content-Type: application/json'
            ]);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            
            $response = curl_exec($ch);
            $httpcode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);
            
            if ($httpcode === 200) {
                return true;
            } else {
                Log::warning("FCM API returned $httpcode: $response");
                return false;
            }
        } catch (\Exception $e) {
            Log::error("FCM Send Error: " . $e->getMessage());
            return false;
        }
    }
}
