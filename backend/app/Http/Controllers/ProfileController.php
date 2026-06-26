<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

use Illuminate\Support\Facades\Auth;
use App\Models\User;
use App\Models\CreatorApplication;

class ProfileController extends Controller
{
    public function getProfile()
    {
        $user = Auth::guard('api')->user();

        $application = CreatorApplication::where('user_id', $user->id)
            ->orderBy('applied_at', 'desc')
            ->first();

        $userData = $user->toArray();
        if ($application) {
            $userData['application'] = $application;
        }

        return response()->json([
            'success' => true,
            'data' => $userData,
        ]);
    }

    public function updateProfile(Request $request)
    {
        $user = Auth::guard('api')->user();

        $request->validate([
            'name' => 'sometimes|string|min:2|max:100',
            'phone' => 'nullable|regex:/^(\+62|62|0)8[0-9]{8,11}$/',
            'selected_pihak' => 'sometimes|string|max:50',
        ], [
            'phone.regex' => 'Nomor telepon tidak valid.',
        ]);

        if ($request->has('name')) $user->name = $request->name;
        if ($request->has('phone')) $user->phone = $request->phone;
        if ($request->has('selected_pihak')) $user->selected_pihak = $request->selected_pihak;
        
        if ($request->has('avatar_url')) {
            $avatarUrl = $request->avatar_url;
            if (str_starts_with($avatarUrl, 'data:image')) {
                // Parse base64
                if (preg_match('/^data:image\/(\w+);base64,/', $avatarUrl, $type)) {
                    $data = substr($avatarUrl, strpos($avatarUrl, ',') + 1);
                    $type = strtolower($type[1]); // png, jpg, jpeg, gif
                    if (in_array($type, ['jpg', 'jpeg', 'gif', 'png'])) {
                        $data = str_replace(' ', '+', $data);
                        $data = base64_decode($data);
                        if ($data !== false) {
                            $fileName = 'avatar_' . $user->id . '_' . time() . '.' . $type;
                            $dirPath = public_path('avatars');
                            if (!file_exists($dirPath)) {
                                mkdir($dirPath, 0755, true);
                            }
                            file_put_contents($dirPath . '/' . $fileName, $data);
                            $user->avatar_url = url('avatars/' . $fileName);
                        }
                    }
                }
            } else {
                $user->avatar_url = $avatarUrl;
            }
        }

        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Profil berhasil diperbarui.',
            'data' => $user
        ]);
    }

    public function applyCreator(Request $request)
    {
        $user = Auth::guard('api')->user();

        $request->validate([
            'pihak_category' => 'required|string|max:50',
            'skill_description' => 'required|string|min:20|max:2000',
            'portfolio_link' => 'required|url|max:255',
            'experience' => 'nullable|string|max:2000',
            'nik' => 'required|regex:/^\d{16}$/',
            'full_name_ktp' => 'required|string|min:3|max:150|regex:/^[A-Za-z\s\.\',-]+$/',
            'birth_place' => 'required|string|min:2|max:100|regex:/^[A-Za-z\s\.\',-]+$/',
            'birth_date' => 'required|date|date_format:Y-m-d|before:today',
            'address_ktp' => 'required|string|min:10|max:500',
            'ktp_photo_url' => 'required|string',
            'selfie_photo_url' => 'required|string',
        ], [
            'nik.regex' => 'NIK harus 16 digit angka.',
            'full_name_ktp.regex' => 'Nama KTP hanya boleh huruf dan spasi.',
            'birth_place.regex' => 'Tempat lahir hanya boleh huruf.',
            'birth_date.before' => 'Tanggal lahir tidak valid.',
            'portfolio_link.url' => 'Link portfolio harus URL valid (https://...).',
            'skill_description.min' => 'Deskripsi keahlian minimal 20 karakter.',
        ]);

        // Check if there is already a pending application
        $existing = CreatorApplication::where('user_id', $user->id)
            ->where('status', 'pending')
            ->first();

        if ($existing) {
            return response()->json([
                'success' => false,
                'message' => 'Anda sudah memiliki pengajuan kreator yang sedang diproses.'
            ], 422);
        }

        try {
            \Illuminate\Support\Facades\DB::beginTransaction();

            $ktpPhotoUrl = $this->saveKtpPhoto($user, $request->ktp_photo_url);
            $selfiePhotoUrl = $this->saveSelfiePhoto($user, $request->selfie_photo_url);

            if (empty($ktpPhotoUrl)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Foto KTP gagal diupload. Pastikan format JPG/PNG dan ukuran tidak terlalu besar.',
                ], 422);
            }

            if (empty($selfiePhotoUrl)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Foto selfie gagal diupload. Pastikan format JPG/PNG dan ukuran tidak terlalu besar.',
                ], 422);
            }
            $app = CreatorApplication::create([
                'user_id' => $user->id,
                'pihak_category' => $request->pihak_category,
                'skill_description' => $request->skill_description,
                'portfolio_link' => $request->portfolio_link,
                'experience' => $request->experience,
                'ktp_photo_url' => $ktpPhotoUrl,
                'selfie_photo_url' => $selfiePhotoUrl,
                'nik' => $request->nik,
                'full_name_ktp' => $request->full_name_ktp,
                'birth_place' => $request->birth_place,
                'birth_date' => $request->birth_date,
                'address_ktp' => $request->address_ktp,
                'status' => 'pending',
                'applied_at' => now(),
            ]);

            // Get category name
            $cat = \App\Models\PihakCategory::where('slug', $request->pihak_category)->first();
            $pihakName = $cat ? $cat->name : ucfirst($request->pihak_category);

            // 2. Send submission confirmation notification
            \App\Models\Notification::create([
                'user_id' => $user->id,
                'title' => 'Pengajuan Kreator Dikirim',
                'message' => "Pengajuan Anda sebagai Kreator kategori {$pihakName} berhasil dikirim dan sedang ditinjau oleh Admin.",
                'type' => 'creator_applied',
                'is_read' => false,
                'created_at' => now(),
            ]);

            \Illuminate\Support\Facades\DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Pengajuan Kreator berhasil dikirim.',
                'data' => $user
            ]);

        } catch (\Exception $e) {
            \Illuminate\Support\Facades\DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Gagal mengirim pengajuan kreator: ' . $e->getMessage()
            ], 500);
        }
    }

    private function saveKtpPhoto(User $user, string $ktpPhotoUrl): ?string
    {
        if (!str_starts_with($ktpPhotoUrl, 'data:image')) {
            return $ktpPhotoUrl;
        }

        if (preg_match('/^data:image\/(\w+);base64,/', $ktpPhotoUrl, $type)) {
            $data = substr($ktpPhotoUrl, strpos($ktpPhotoUrl, ',') + 1);
            $ext = strtolower($type[1]);
            if (in_array($ext, ['jpg', 'jpeg', 'gif', 'png'])) {
                $data = str_replace(' ', '+', $data);
                $decoded = base64_decode($data);
                if ($decoded !== false) {
                    $fileName = 'ktp_' . $user->id . '_' . time() . '.' . $ext;
                    $dirPath = public_path('ktp');
                    if (!file_exists($dirPath)) {
                        mkdir($dirPath, 0755, true);
                    }
                    file_put_contents($dirPath . '/' . $fileName, $decoded);
                    return url('ktp/' . $fileName);
                }
            }
        }

        return null;
    }

    private function saveSelfiePhoto(User $user, string $selfiePhotoUrl): ?string
    {
        if (!str_starts_with($selfiePhotoUrl, 'data:image')) {
            return $selfiePhotoUrl;
        }

        if (preg_match('/^data:image\/(\w+);base64,/', $selfiePhotoUrl, $type)) {
            $data = substr($selfiePhotoUrl, strpos($selfiePhotoUrl, ',') + 1);
            $ext = strtolower($type[1]);
            if (in_array($ext, ['jpg', 'jpeg', 'gif', 'png'])) {
                $data = str_replace(' ', '+', $data);
                $decoded = base64_decode($data);
                if ($decoded !== false) {
                    $fileName = 'selfie_' . $user->id . '_' . time() . '.' . $ext;
                    $dirPath = public_path('selfie');
                    if (!file_exists($dirPath)) {
                        mkdir($dirPath, 0755, true);
                    }
                    file_put_contents($dirPath . '/' . $fileName, $decoded);
                    return url('selfie/' . $fileName);
                }
            }
        }

        return null;
    }
}
