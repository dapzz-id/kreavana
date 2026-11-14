<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\UserKyc;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Tymon\JWTAuth\Facades\JWTAuth;

class KycController
{
    /**
     * Submit or update legal KYC documents.
     */
    public function submit(Request $request)
    {
        $user = JWTAuth::parseToken()->authenticate();

        $validator = Validator::make($request->all(), [
            'nik' => 'required|string|size:16|unique:user_kyc,nik,' . ($user->kyc?->id ?? 'NULL') . ',id',
            'full_name_ktp' => 'required|string|max:255',
            'ktp_photo_url' => 'required|string|url|max:500',
            'selfie_photo_url' => 'required|string|url|max:500',
            'nib_number' => 'nullable|string|max:50',
            'nib_file_url' => 'nullable|string|url|max:500',
            'verification_type' => 'nullable|string|in:individual,business',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Validasi dokumen KYC gagal.',
                'errors' => $validator->errors(),
            ], 422);
        }

        $kyc = UserKyc::updateOrCreate(
            ['user_id' => $user->id],
            [
                'nik' => $request->nik,
                'full_name_ktp' => $request->full_name_ktp,
                'ktp_photo_url' => $request->ktp_photo_url,
                'selfie_photo_url' => $request->selfie_photo_url,
                'nib_number' => $request->nib_number,
                'nib_file_url' => $request->nib_file_url,
                'verification_type' => $request->verification_type ?? 'individual',
                'status' => 'pending',
                'submitted_at' => now(),
            ]
        );

        return response()->json([
            'status' => true,
            'message' => 'Dokumen verifikasi KYC berhasil dikirim untuk ditinjau.',
            'data' => $kyc,
        ]);
    }

    /**
     * Get KYC Verification Status.
     */
    public function getStatus(Request $request)
    {
        $user = JWTAuth::parseToken()->authenticate();
        $kyc = $user->kyc;

        return response()->json([
            'status' => true,
            'data' => [
                'is_verified' => $kyc?->status === 'approved',
                'status' => $kyc?->status ?? 'unverified',
                'verification_type' => $kyc?->verification_type,
                'verified_at' => $kyc?->verified_at,
                'rejection_reason' => $kyc?->rejection_reason,
            ],
        ]);
    }
}
