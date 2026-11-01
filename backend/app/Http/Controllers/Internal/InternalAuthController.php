<?php

namespace App\Http\Controllers\Internal;

use App\Http\Controllers\Controller;
use App\Models\AuthLog;
use App\Models\User;
use App\Services\JtiService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class InternalAuthController extends Controller
{
    /**
     * Handle backchannel session revocation broadcast from users_api / IAM.
     */
    public function revokeSession(Request $request)
    {
        $request->validate([
            'user_id' => 'nullable|string',
            'email' => 'nullable|string|email',
            'jti' => 'nullable|string',
            'reason' => 'nullable|string',
        ]);

        $userId = $request->user_id;
        $email = $request->email;
        $jti = $request->jti;
        $reason = $request->reason ?? 'universal_logout';

        if ($jti) {
            JtiService::revoke($jti);
        }

        // Find user by ID or email
        $user = null;
        if ($userId) {
            $user = User::find($userId);
        }
        if (!$user && $email) {
            $user = User::where('email', $email)->first();
        }

        AuthLog::create([
            'user_id' => $user?->id,
            'action' => 'session_revoked_by_iam',
            'ip_address' => $request->ip(),
            'user_agent' => substr((string) ($request->userAgent() ?: 'users_api_internal_agent'), 0, 255),
        ]);

        Log::info('InternalAuthController::revokeSession processed', [
            'user_id' => $user?->id,
            'email' => $email,
            'reason' => $reason,
            'correlation_id' => $request->get('correlation_id'),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Backchannel session revocation successfully processed.',
        ]);
    }

    /**
     * Handle backchannel user suspension synchronization from users_api / IAM.
     */
    public function syncSuspension(Request $request)
    {
        $request->validate([
            'user_id' => 'nullable|string',
            'email' => 'nullable|string|email',
            'is_suspended' => 'required|boolean',
            'suspended_until' => 'nullable|date',
            'reason' => 'nullable|string',
        ]);

        $userId = $request->user_id;
        $email = $request->email;
        $isSuspended = (bool) $request->is_suspended;
        $suspendedUntil = $request->suspended_until ? now()->parse($request->suspended_until) : null;
        $reason = $request->reason;

        $user = null;
        if ($userId) {
            $user = User::find($userId);
        }
        if (!$user && $email) {
            $user = User::where('email', $email)->first();
        }

        if (!$user) {
            return response()->json([
                'status' => false,
                'message' => 'Shadow user record not found in backend.',
            ], 404);
        }

        $user->is_suspended = $isSuspended;
        $user->suspended_until = $isSuspended ? $suspendedUntil : null;
        $user->suspend_reason = $isSuspended ? $reason : null;
        $user->save();

        AuthLog::create([
            'user_id' => $user->id,
            'action' => $isSuspended ? 'user_suspended_by_iam' : 'user_unsuspended_by_iam',
            'ip_address' => $request->ip(),
            'user_agent' => substr((string) ($request->userAgent() ?: 'users_api_internal_agent'), 0, 255),
        ]);

        Log::info('InternalAuthController::syncSuspension processed', [
            'user_id' => $user->id,
            'is_suspended' => $isSuspended,
            'reason' => $reason,
            'correlation_id' => $request->get('correlation_id'),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'User suspension status synchronized successfully.',
            'data' => [
                'user_id' => $user->id,
                'is_suspended' => $user->is_suspended,
            ],
        ]);
    }
}
