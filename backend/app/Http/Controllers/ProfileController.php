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
        return response()->json([
            'success' => true,
            'data' => $user
        ]);
    }

    public function updateProfile(Request $request)
    {
        $user = Auth::guard('api')->user();

        // Validasi opsional
        $request->validate([
            'name' => 'sometimes|string|max:100',
            'phone' => 'nullable|string|max:20',
            'selected_pihak' => 'sometimes|string|max:50',
            // avatar ditangani terpisah atau via base64/url
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
            'pihak_category' => 'required|string',
            'skill_description' => 'required|string',
            'portfolio_link' => 'nullable|string',
            'experience' => 'nullable|string',
        ]);

        try {
            \Illuminate\Support\Facades\DB::beginTransaction();

            // 1. Create creator application (Auto-approved for demo)
            CreatorApplication::create([
                'user_id' => $user->id,
                'pihak_category' => $request->pihak_category,
                'skill_description' => $request->skill_description,
                'portfolio_link' => $request->portfolio_link,
                'experience' => $request->experience,
                'status' => 'approved',
                'admin_note' => 'Disetujui otomatis untuk demo sistem.',
                'applied_at' => now(),
                'reviewed_at' => now(),
            ]);

            // 2. Update user
            $user->role = 'creator';
            $user->is_creator_approved = true;
            $user->selected_pihak = $request->pihak_category;
            $user->save();

            // 3. Upsert user_pihak to active 'creator' role for this category
            \App\Models\UserPihak::updateOrCreate(
                [
                    'user_id' => $user->id,
                    'pihak_slug' => $request->pihak_category,
                    'role_type' => 'creator',
                ],
                [
                    'is_active' => true,
                    'joined_at' => now(),
                ]
            );

            // 4. Also add the user role 'user' for this category
            \App\Models\UserPihak::updateOrCreate(
                [
                    'user_id' => $user->id,
                    'pihak_slug' => $request->pihak_category,
                    'role_type' => 'user',
                ],
                [
                    'is_active' => true,
                    'joined_at' => now(),
                ]
            );

            // Get category name
            $cat = \App\Models\PihakCategory::where('slug', $request->pihak_category)->first();
            $pihakName = $cat ? $cat->name : ucfirst($request->pihak_category);

            // 5. Send notification
            \App\Models\Notification::create([
                'user_id' => $user->id,
                'title' => 'Pengajuan Kreator Disetujui!',
                'message' => "Selamat! Pengajuan Anda sebagai Kreator di kategori {$pihakName} telah disetujui. Dashboard Kreator Anda kini aktif.",
                'type' => 'creator_approved',
                'is_read' => false,
                'created_at' => now(),
            ]);

            \Illuminate\Support\Facades\DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Pengajuan Kreator berhasil disetujui.',
                'data' => $user
            ]);

        } catch (\Exception $e) {
            \Illuminate\Support\Facades\DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Gagal memproses pengajuan kreator: ' . $e->getMessage()
            ], 500);
        }
    }
}
