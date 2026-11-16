<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\UserCredential;
use App\Services\TokenService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class PasswordResetController
{
    public function __construct(
        protected TokenService $tokenService
    ) {}

    /**
     * Internal S2S: Issue a 6-digit password reset OTP in password_reset_tokens.
     */
    public function requestReset(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|string|email',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Format alamat email tidak valid.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $email = strtolower(trim((string) $request->input('email')));
        $user = User::whereRaw('LOWER(email) = ?', [$email])->first();

        if (!$user || !$user->is_active || $user->is_suspended) {
            return response()->json([
                'status' => true,
                'data' => [
                    'found' => false,
                ],
            ]);
        }

        $otp = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
        $canonicalEmail = strtolower($user->email);

        DB::table('password_reset_tokens')->updateOrInsert(
            ['email' => $canonicalEmail],
            [
                'token_hash' => Hash::make($otp),
                'attempts' => 0,
                'expires_at' => now()->addMinutes(15),
                'created_at' => now(),
            ]
        );

        return response()->json([
            'status' => true,
            'data' => [
                'found' => true,
                'email' => $canonicalEmail,
                'name' => $user->display_name ?? $user->full_name,
                'otp' => $otp,
            ],
        ]);
    }

    /**
     * Internal S2S: Validate 6-digit reset OTP, update UserCredential password, and revoke active sessions.
     */
    public function confirmReset(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|string|email',
            'code' => 'required|string|size:6|regex:/^[0-9]{6}$/',
            'password' => 'required|string|min:8|confirmed',
        ], [
            'email.required' => 'Alamat email wajib diisi.',
            'email.email' => 'Format email tidak valid.',
            'code.required' => 'Kode verifikasi reset wajib diisi.',
            'code.size' => 'Kode verifikasi harus 6 digit angka.',
            'code.regex' => 'Kode verifikasi harus berupa 6 digit angka.',
            'password.required' => 'Kata sandi baru wajib diisi.',
            'password.min' => 'Kata sandi baru minimal 8 karakter.',
            'password.confirmed' => 'Konfirmasi kata sandi tidak cocok.',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => $validator->errors()->first(),
                'errors' => $validator->errors(),
            ], 422);
        }

        $email = strtolower(trim((string) $request->input('email')));
        $code = (string) $request->input('code');
        $newPassword = (string) $request->input('password');

        $outcome = DB::transaction(function () use ($email, $code, $newPassword) {
            $user = User::whereRaw('LOWER(email) = ?', [$email])->first();
            if (!$user || !$user->is_active || $user->is_suspended) {
                return 'invalid_reset_code';
            }

            $canonicalEmail = strtolower($user->email);
            $record = DB::table('password_reset_tokens')
                ->where('email', $canonicalEmail)
                ->lockForUpdate()
                ->first();

            if (!$record) {
                return 'invalid_reset_code';
            }

            if (Carbon::parse($record->expires_at)->isPast()) {
                return 'reset_code_expired';
            }

            if ((int) $record->attempts >= 5) {
                return 'reset_attempts_exceeded';
            }

            if (!Hash::check($code, $record->token_hash)) {
                DB::table('password_reset_tokens')
                    ->where('email', $canonicalEmail)
                    ->update(['attempts' => ((int) $record->attempts) + 1]);

                return 'invalid_reset_code';
            }

            $existingCredential = $user->credential;
            $verifiedAt = $existingCredential?->email_verified_at ?? now();

            UserCredential::updateOrCreate(
                ['user_id' => $user->id],
                [
                    'password_hash' => Hash::make($newPassword),
                    'password_changed_at' => now(),
                    'failed_login_attempts' => 0,
                    'locked_until' => null,
                    'is_email_verified' => true,
                    'email_verified_at' => $verifiedAt,
                ]
            );

            DB::table('password_reset_tokens')
                ->where('email', $canonicalEmail)
                ->delete();

            $this->tokenService->revokeAllSessionsForUser($user->id);

            return [
                'status' => 'success',
                'user_id' => $user->id,
                'email' => $user->email,
            ];
        });

        if (is_array($outcome) && ($outcome['status'] ?? null) === 'success') {
            return response()->json([
                'status' => true,
                'message' => 'Kata sandi berhasil diatur ulang. Silakan masuk dengan kata sandi baru Anda.',
                'data' => [
                    'user_id' => $outcome['user_id'],
                    'email' => $outcome['email'],
                ],
            ]);
        }

        return match ($outcome) {
            'reset_code_expired' => response()->json([
                'status' => false,
                'message' => 'Kode reset kata sandi sudah kedaluwarsa. Silakan minta kode baru.',
                'error_code' => 'reset_code_expired',
            ], 422),
            'reset_attempts_exceeded' => response()->json([
                'status' => false,
                'message' => 'Terlalu banyak percobaan gagal. Silakan minta kode reset baru.',
                'error_code' => 'reset_attempts_exceeded',
            ], 422),
            default => response()->json([
                'status' => false,
                'message' => 'Kode reset kata sandi tidak valid.',
                'error_code' => 'invalid_reset_code',
            ], 422),
        };
    }
}
