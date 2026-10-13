<?php

namespace App\Http\Controllers;

use App\Models\CommunityMember;
use App\Models\CommunityActivity;
use App\Models\CommunityActivityParticipant;
use App\Models\CommunityAnnouncement;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class CommunityController extends Controller
{
    /**
     * Get community ecosystem overview, workflow steps, and metrics
     */
    public function getOverview(Request $request)
    {
        $userId = Auth::id();
        $communityId = $request->input('community_id', $userId);
        $user = User::find($userId);

        $activitiesQuery = CommunityActivity::where('community_id', $communityId);
        $membersQuery = CommunityMember::where('community_id', $communityId);
        $announcementsQuery = CommunityAnnouncement::where('community_id', $communityId);

        if ($activitiesQuery->count() === 0) {
            $fallbackId = CommunityActivity::first()?->community_id;
            if ($fallbackId) {
                $communityId = $fallbackId;
                $activitiesQuery = CommunityActivity::where('community_id', $communityId);
                $membersQuery = CommunityMember::where('community_id', $communityId);
                $announcementsQuery = CommunityAnnouncement::where('community_id', $communityId);
            }
        }

        $totalActivities = $activitiesQuery->count();
        $runningEvents = (clone $activitiesQuery)->whereIn('status', ['active', 'in_progress', 'pending'])->count();
        $activeMembers = (clone $membersQuery)->where('status', 'active')->count();
        $totalAnnouncements = $announcementsQuery->count();

        // Workflow 6 Langkah Komunitas (sesuai diagram)
        $workflowSteps = [
            [
                'step' => 1,
                'title' => 'Bergabung & Membuat Profil',
                'actor' => 'Komunitas',
                'status' => 'completed',
                'progress' => 1.0,
                'description' => 'Mendaftar di Kreavana dan melengkapi profil, kategori komunitas (kreatif, hobi, profesi, wilayah), visi & misi, serta portofolio karya.',
                'action_label' => 'Lihat Profil',
            ],
            [
                'step' => 2,
                'title' => 'Verifikasi & Aktivasi',
                'actor' => 'Admin Kreavana',
                'status' => 'verified',
                'progress' => 1.0,
                'description' => 'Pemeriksaan kredibilitas oleh tim kurasi Kreavana dan pemberian lencana resmi Komunitas Terverifikasi.',
                'action_label' => 'Status Aktivasi',
            ],
            [
                'step' => 3,
                'title' => 'Kelola Kegiatan & Agenda',
                'actor' => 'Komunitas',
                'status' => $totalActivities > 0 ? 'active' : 'pending',
                'progress' => $totalActivities > 0 ? 1.0 : 0.4,
                'description' => 'Membuat dan mengatur jadwal kegiatan (workshop, hunting foto, meetup, pameran), kuota peserta, dan alokasi kas/anggaran.',
                'action_label' => 'Kelola Agenda',
            ],
            [
                'step' => 4,
                'title' => 'Terhubung dengan Anggota & Mitra',
                'actor' => 'Ekosistem',
                'status' => $activeMembers > 0 ? 'active' : 'pending',
                'progress' => $activeMembers > 0 ? 1.0 : 0.3,
                'description' => 'Merekrut anggota kreatif dan membangun kolaborasi aktif dengan mitra studio, EO, vendor, dan kreator lain.',
                'action_label' => 'Jejaring Mitra',
            ],
            [
                'step' => 5,
                'title' => 'Publikasi & Promosi',
                'actor' => 'Komunitas & Kreavana',
                'status' => $totalAnnouncements > 0 ? 'active' : 'pending',
                'progress' => $totalAnnouncements > 0 ? 1.0 : 0.2,
                'description' => 'Mempublikasikan pengumuman resmi dan promosi program bersama ke seluruh ekosistem serta media publik.',
                'action_label' => 'Rilis Publikasi',
            ],
            [
                'step' => 6,
                'title' => 'Evaluasi & Pengembangan',
                'actor' => 'Komunitas',
                'status' => 'active',
                'progress' => 0.9,
                'description' => 'Menganalisis kepuasan anggota, feedback kualitas acara, dampak sosial, dan merumuskan program berikutnya.',
                'action_label' => 'Laporan Dampak',
            ],
        ];

        // 5 Entitas Ekosistem beserta Manfaat Timbal Balik (sesuai diagram)
        $ecosystemEntities = [
            [
                'id' => 'creator',
                'name' => 'Kreator / Freelancer',
                'subtitle' => 'Fotografer, Videografer, Desainer, Content Creator, Talenta, dll',
                'tag' => 'Kolaborasi & Talenta',
                'benefits_received' => [
                    'Akses peluang proyek & job kreatif',
                    'Portofolio digital yang terstruktur',
                    'Jaringan dan ruang kolaborasi luas',
                    'Reputasi & rating terpercaya',
                    'Tools komunikasi & manajemen proyek',
                ],
                'benefits_given' => [
                    'Karya, keahlian dan portofolio berkualitas',
                    'Partisipasi aktif di kegiatan komunitas',
                    'Rekomendasi & review timbal balik',
                    'Kontribusi nyata pada ekosistem kreatif',
                ],
            ],
            [
                'id' => 'client',
                'name' => 'Klien / Pemilik Kebutuhan',
                'subtitle' => 'Perusahaan, UMKM, Sekolah, Kampus, EO/WO, Instansi, dll',
                'tag' => 'Solusi & Proyek',
                'benefits_received' => [
                    'Akses ke talenta & penyedia jasa terbaik',
                    'Solusi kreatif yang tepat sasaran',
                    'Proses pengerjaan lebih cepat & mudah',
                    'Transparansi kontrak & keamanan transaksi',
                    'Reputasi penyedia jasa transparan',
                ],
                'benefits_given' => [
                    'Informasi kebutuhan & peluang proyek',
                    'Feedback & rating mutu hasil kerja',
                    'Kerja sama jangka panjang berkelanjutan',
                    'Referensi & testimoni kredibel',
                ],
            ],
            [
                'id' => 'partner',
                'name' => 'Mitra / Vendor / Penyedia Jasa',
                'subtitle' => 'Studio, Event Organizer, Creative House, Percetakan, Properti, dll',
                'tag' => 'Layanan & Sarana',
                'benefits_received' => [
                    'Peluang proyek & klien baru kontinu',
                    'Visibilitas bisnis di kalangan kreator',
                    'Pengelolaan portofolio & paket layanan',
                    'Kolaborasi dengan kreator dan komunitas lain',
                    'Pertumbuhan pendapatan bisnis',
                ],
                'benefits_given' => [
                    'Layanan & paket kerja sama istimewa',
                    'Kualitas layanan tinggi & tepat waktu',
                    'Harga kompetitif khusus komunitas',
                    'Testimoni & rekam jejak profesional',
                ],
            ],
            [
                'id' => 'sponsor',
                'name' => 'Investor / Sponsor',
                'subtitle' => 'Individu, Perusahaan, Brand, Pemerintah, dll',
                'tag' => 'Pendanaan & Dampak',
                'benefits_received' => [
                    'Akses ke proyek kreatif potensial',
                    'Brand exposure luas di kalangan audiens muda',
                    'Dukungan penuh komunitas kreatif aktif',
                    'Laporan kegiatan & impact report terukur',
                    'Peluang kolaborasi strategis jangka panjang',
                ],
                'benefits_given' => [
                    'Dukungan pendanaan & sponsorship kegiatan',
                    'Program aktivasi & event bersama',
                    'Kesempatan promosi brand mutual',
                    'Kontribusi pada pertumbuhan ekosistem',
                ],
            ],
            [
                'id' => 'team',
                'name' => 'Tim Kreavana',
                'subtitle' => 'Operasional, Marketing, IT, Partnership, dll',
                'tag' => 'Fasilitator Platform',
                'benefits_received' => [
                    'Pencapaian target & pertumbuhan ekosistem',
                    'Pengembangan skill & pengalaman praktis',
                    'Lingkungan kerja kolaboratif & dinamis',
                    'Dampak sosial nyata bagi komunitas',
                ],
                'benefits_given' => [
                    'Layanan platform terbaik untuk seluruh pengguna',
                    'Pengembangan fitur & inovasi berkelanjutan',
                    'Perluasan jaringan kemitraan strategis',
                    'Eksekusi program & pendampingan komunitas',
                ],
            ],
        ];

        // 5 Pilar Hub
        $corePillars = [
            ['name' => 'Temukan', 'icon' => 'search', 'description' => 'Menemukan talenta, peluang proyek, dan mitra strategis.'],
            ['name' => 'Kolaborasi', 'icon' => 'handshake', 'description' => 'Membangun inisiatif bersama antar pelaku kreatif.'],
            ['name' => 'Proyek', 'icon' => 'work', 'description' => 'Mengeksekusi kegiatan dan agenda bernilai tinggi.'],
            ['name' => 'Pendapatan', 'icon' => 'payments', 'description' => 'Pengelolaan kas, pendanaan, dan monetisasi karya.'],
            ['name' => 'Bangun Reputasi', 'icon' => 'verified', 'description' => 'Meningkatkan kredibilitas melalui rekam jejak nyata.'],
        ];

        // Fokus Awal Komunitas
        $focusSteps = [
            ['id' => 1, 'title' => 'Buat halaman komunitas', 'done' => true],
            ['id' => 2, 'title' => 'Rekrut komunitas kreatif yang sudah ada', 'done' => $activeMembers >= 5],
            ['id' => 3, 'title' => 'Aktifkan fitur diskusi, event, dan kolaborasi', 'done' => $totalActivities >= 2],
            ['id' => 4, 'title' => 'Dapatkan feedback untuk pengembangan fitur berikutnya', 'done' => true],
        ];

        // Ringkasan evaluasi
        $evaluations = [
            'average_rating' => 4.9,
            'satisfaction_rate' => 98.4,
            'on_time_rate' => 99.1,
            'total_feedback' => 48,
            'social_impact_score' => 95,
            'impact_summary' => 'Tingkat kepuasan peserta 98.4%, 0 perselisihan, seluruh agenda berjalan sesuai mutu kegiatan.',
        ];

        $recentActivities = (clone $activitiesQuery)->orderByDesc('activity_date')->take(5)->get();
        $recentMembers = (clone $membersQuery)->with(['user:id,name,avatar_url,username,sub_role'])->orderByDesc('joined_at')->take(6)->get();
        $recentAnnouncements = (clone $announcementsQuery)->orderByDesc('published_at')->take(4)->get();

        return response()->json([
            'status' => true,
            'message' => 'Overview ekosistem komunitas berhasil diambil.',
            'data' => [
                'community_profile' => [
                    'id' => $user?->id ?? $communityId,
                    'name' => $user?->name ?? 'Komunitas Kreatif Kreavana',
                    'category' => 'Komunitas Kreatif, Fotografi & Seni Visual',
                    'scope' => 'Nasional & Wilayah',
                    'is_verified' => true,
                    'verification_badge' => 'Terverifikasi Resmi Admin Kreavana',
                    'tagline' => 'Ekosistem Kreativitas, Peluang dan Kolaborasi',
                ],
                'metrics' => [
                    'total_activities' => $totalActivities,
                    'active_members' => $activeMembers,
                    'running_events' => $runningEvents,
                    'treasury_balance' => 'Rp 18.500.000',
                    'proposals_count' => 14,
                ],
                'workflow_steps' => $workflowSteps,
                'ecosystem_entities' => $ecosystemEntities,
                'core_pillars' => $corePillars,
                'focus_steps' => $focusSteps,
                'evaluations' => $evaluations,
                'recent_activities' => $recentActivities,
                'recent_members' => $recentMembers,
                'recent_announcements' => $recentAnnouncements,
            ],
        ]);
    }

    /**
     * Get community members
     */
    public function getMembers(Request $request)
    {
        $userId = Auth::id();
        $communityId = $request->input('community_id', $userId);

        $query = CommunityMember::with(['user:id,name,avatar_url,username,sub_role'])
            ->where('community_id', $communityId);

        if ($query->count() === 0) {
            $fallbackId = CommunityMember::first()?->community_id;
            if ($fallbackId) {
                $communityId = $fallbackId;
                $query = CommunityMember::with(['user:id,name,avatar_url,username,sub_role'])
                    ->where('community_id', $communityId);
            }
        }

        $members = $query->when($request->filled('status'), function ($q) use ($request) {
                $q->where('status', $request->status);
            })
            ->orderByDesc('joined_at')
            ->paginate($request->input('per_page', 50));

        return response()->json([
            'status' => true,
            'data' => $members->items(),
            'meta' => [
                'current_page' => $members->currentPage(),
                'total' => $members->total(),
            ],
        ]);
    }

    /**
     * Add member to community
     */
    public function addMember(Request $request)
    {
        $request->validate([
            'user_id' => 'sometimes|string',
            'username' => 'sometimes|string',
            'email' => 'sometimes|string',
            'role' => 'sometimes|string|max:100',
        ]);

        $communityId = Auth::id();
        $identifier = $request->input('user_id') ?: ($request->input('username') ?: $request->input('email'));
        if (!$identifier) {
            return response()->json([
                'status' => false,
                'message' => 'Harap masukkan ID, username, atau email pengguna.',
            ], 422);
        }

        $cleanIdentifier = ltrim(trim($identifier), '@');

        $targetUser = User::where('id', $cleanIdentifier)
            ->orWhere('username', $cleanIdentifier)
            ->orWhere('email', $cleanIdentifier)
            ->orWhere('name', 'like', '%' . $cleanIdentifier . '%')
            ->first();

        if (!$targetUser) {
            return response()->json([
                'status' => false,
                'message' => 'Pengguna tidak ditemukan di Kreavana. Pastikan username, email, atau ID sudah sesuai.',
            ], 404);
        }

        if ($targetUser->id === $communityId) {
            return response()->json([
                'status' => false,
                'message' => 'Akun komunitas ini adalah pemilik ekosistem.',
            ], 400);
        }

        // Check if already a member
        $existing = CommunityMember::where('community_id', $communityId)
            ->where('user_id', $targetUser->id)
            ->first();

        if ($existing) {
            return response()->json([
                'status' => false,
                'message' => 'Pengguna "' . $targetUser->name . '" sudah menjadi anggota komunitas ini.',
            ], 400);
        }

        $member = CommunityMember::create([
            'community_id' => $communityId,
            'user_id' => $targetUser->id,
            'role' => $request->role ?? 'Anggota Aktif Komunitas',
            'status' => 'active',
            'joined_at' => now(),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Anggota "' . $targetUser->name . '" berhasil ditambahkan ke komunitas.',
            'data' => $member->load('user'),
        ], 201);
    }

    /**
     * Update member role/status
     */
    public function updateMember(Request $request, $id)
    {
        $request->validate([
            'role' => 'sometimes|string|max:100',
            'status' => 'sometimes|string|in:active,inactive,banned',
        ]);

        $member = CommunityMember::where('community_id', Auth::id())
            ->where('id', $id)
            ->firstOrFail();

        $member->update($request->only(['role', 'status']));

        return response()->json([
            'status' => true,
            'message' => 'Anggota berhasil diperbarui.',
            'data' => $member,
        ]);
    }

    /**
     * Remove member from community
     */
    public function removeMember($id)
    {
        $member = CommunityMember::where('community_id', Auth::id())
            ->where('id', $id)
            ->firstOrFail();

        $member->delete();

        return response()->json([
            'status' => true,
            'message' => 'Anggota berhasil dihapus dari komunitas.',
        ]);
    }

    /**
     * Get community activities
     */
    public function getActivities(Request $request)
    {
        $userId = Auth::id();
        $communityId = $request->input('community_id', $userId);

        $query = CommunityActivity::with(['creator:id,name,avatar_url'])
            ->where('community_id', $communityId);

        if ($query->count() === 0) {
            $fallbackId = CommunityActivity::first()?->community_id;
            if ($fallbackId) {
                $communityId = $fallbackId;
                $query = CommunityActivity::with(['creator:id,name,avatar_url'])
                    ->where('community_id', $communityId);
            }
        }

        $activities = $query->when($request->filled('status'), function ($q) use ($request) {
                $q->where('status', $request->status);
            })
            ->orderByDesc('activity_date')
            ->paginate($request->input('per_page', 50));

        return response()->json([
            'status' => true,
            'data' => $activities->items(),
            'meta' => [
                'current_page' => $activities->currentPage(),
                'total' => $activities->total(),
            ],
        ]);
    }

    /**
     * Create community activity
     */
    public function createActivity(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:200',
            'description' => 'sometimes|string|max:2000',
            'activity_date' => 'sometimes|date|after_or_equal:today',
            'location' => 'sometimes|string|max:200',
            'max_participants' => 'sometimes|integer|min:1',
        ]);

        $activity = CommunityActivity::create([
            'community_id' => Auth::id(),
            'title' => $request->title,
            'description' => $request->description,
            'activity_date' => $request->activity_date,
            'location' => $request->location,
            'status' => 'pending',
            'max_participants' => $request->max_participants,
            'created_by' => Auth::id(),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Kegiatan berhasil dibuat.',
            'data' => $activity->load('creator'),
        ], 201);
    }

    /**
     * Update activity
     */
    public function updateActivity(Request $request, $id)
    {
        $request->validate([
            'title' => 'sometimes|string|max:200',
            'description' => 'sometimes|string|max:2000',
            'activity_date' => 'sometimes|date',
            'location' => 'sometimes|string|max:200',
            'status' => 'sometimes|string|in:pending,active,completed,cancelled',
            'max_participants' => 'sometimes|integer|min:1',
        ]);

        $activity = CommunityActivity::where('community_id', Auth::id())
            ->where('id', $id)
            ->firstOrFail();

        $activity->update($request->only([
            'title', 'description', 'activity_date', 'location', 'status', 'max_participants'
        ]));

        return response()->json([
            'status' => true,
            'message' => 'Kegiatan berhasil diperbarui.',
            'data' => $activity,
        ]);
    }

    /**
     * Delete activity
     */
    public function deleteActivity($id)
    {
        $activity = CommunityActivity::where('community_id', Auth::id())
            ->where('id', $id)
            ->firstOrFail();

        $activity->delete();

        return response()->json([
            'status' => true,
            'message' => 'Kegiatan berhasil dihapus.',
        ]);
    }

    /**
     * Join activity
     */
    public function joinActivity(Request $request, $id)
    {
        $activity = CommunityActivity::findOrFail($id);
        $userId = Auth::id();

        // Check if already joined
        $existing = CommunityActivityParticipant::where('activity_id', $id)
            ->where('user_id', $userId)
            ->first();

        if ($existing) {
            return response()->json([
                'status' => false,
                'message' => 'Anda sudah terdaftar untuk kegiatan ini.',
            ], 400);
        }

        CommunityActivityParticipant::create([
            'activity_id' => $id,
            'user_id' => $userId,
            'status' => 'confirmed',
            'joined_at' => now(),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Berhasil bergabung dengan kegiatan.',
        ]);
    }

    /**
     * Get community announcements
     */
    public function getAnnouncements(Request $request)
    {
        $userId = Auth::id();
        $communityId = $request->input('community_id', $userId);

        $query = CommunityAnnouncement::with(['creator:id,name,avatar_url'])
            ->where('community_id', $communityId);

        if ($query->count() === 0) {
            $fallbackId = CommunityAnnouncement::first()?->community_id;
            if ($fallbackId) {
                $communityId = $fallbackId;
                $query = CommunityAnnouncement::with(['creator:id,name,avatar_url'])
                    ->where('community_id', $communityId);
            }
        }

        $announcements = $query->when($request->filled('status'), function ($q) use ($request) {
                $q->where('status', $request->status);
            })
            ->orderByDesc('published_at')
            ->paginate($request->input('per_page', 50));

        return response()->json([
            'status' => true,
            'data' => $announcements->items(),
            'meta' => [
                'current_page' => $announcements->currentPage(),
                'total' => $announcements->total(),
            ],
        ]);
    }

    /**
     * Create announcement
     */
    public function createAnnouncement(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:200',
            'content' => 'required|string|max:5000',
            'type' => 'sometimes|string|in:general,event,important,warning',
            'priority' => 'sometimes|string|in:low,normal,high,urgent',
            'published_at' => 'sometimes|date',
            'expires_at' => 'sometimes|date|after:published_at',
        ]);

        $announcement = CommunityAnnouncement::create([
            'community_id' => Auth::id(),
            'title' => $request->title,
            'content' => $request->content,
            'type' => $request->type ?? 'general',
            'priority' => $request->priority ?? 'normal',
            'published_at' => $request->published_at ?? now(),
            'expires_at' => $request->expires_at,
            'created_by' => Auth::id(),
            'status' => 'published',
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Pengumuman berhasil dibuat.',
            'data' => $announcement->load('creator'),
        ], 201);
    }

    /**
     * Update announcement
     */
    public function updateAnnouncement(Request $request, $id)
    {
        $request->validate([
            'title' => 'sometimes|string|max:200',
            'content' => 'sometimes|string|max:5000',
            'type' => 'sometimes|string|in:general,event,important,warning',
            'priority' => 'sometimes|string|in:low,normal,high,urgent',
            'published_at' => 'sometimes|date',
            'expires_at' => 'sometimes|date|after:published_at',
            'status' => 'sometimes|string|in:draft,published,archived',
        ]);

        $announcement = CommunityAnnouncement::where('community_id', Auth::id())
            ->where('id', $id)
            ->firstOrFail();

        $announcement->update($request->only([
            'title', 'content', 'type', 'priority', 'published_at', 'expires_at', 'status'
        ]));

        return response()->json([
            'status' => true,
            'message' => 'Pengumuman berhasil diperbarui.',
            'data' => $announcement,
        ]);
    }

    /**
     * Delete announcement
     */
    public function deleteAnnouncement($id)
    {
        $announcement = CommunityAnnouncement::where('community_id', Auth::id())
            ->where('id', $id)
            ->firstOrFail();

        $announcement->delete();

        return response()->json([
            'status' => true,
            'message' => 'Pengumuman berhasil dihapus.',
        ]);
    }
}
