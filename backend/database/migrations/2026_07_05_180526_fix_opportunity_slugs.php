<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Truncate opportunities table
        DB::table('opportunities')->truncate();

        // Get admin user ID
        $adminId = DB::table('users')->where('role', 'admin')->value('id');
        if (!$adminId) {
            $firstUser = DB::table('users')->first();
            if (!$firstUser) {
                return;
            }
            $adminId = $firstUser->id;
        }

        // Insert correct opportunities data with UUIDs
        $opportunities = [
            [
                'id' => (string) Str::uuid(),
                'title' => 'Fotografer Event Jakarta',
                'description' => 'Dibutuhkan fotografer profesional untuk dokumentasi event corporate di Jakarta. Minimal pengalaman 2 tahun.',
                'sub_role_slug' => 'photographer',
                'location' => 'Jakarta',
                'deadline' => '2026-07-15',
                'budget_range' => 'Rp 3.000.000 - Rp 5.000.000',
                'status' => 'open',
                'posted_by' => $adminId,
                'created_at' => now(),
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'MC Pernikahan & Event Korporat',
                'description' => 'Mencari MC profesional untuk acara pernikahan dan event korporat. Pengalaman minimal 2 tahun.',
                'sub_role_slug' => 'mc',
                'location' => 'Bandung',
                'deadline' => '2026-07-20',
                'budget_range' => 'Rp 2.000.000 - Rp 5.000.000',
                'status' => 'open',
                'posted_by' => $adminId,
                'created_at' => now(),
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'Penyanyi Wedding Organizer',
                'description' => 'Butuh penyanyi untuk paket pernikahan premium. Genre: pop, jazz, dan akustik.',
                'sub_role_slug' => 'singer',
                'location' => 'Surabaya',
                'deadline' => '2026-08-01',
                'budget_range' => 'Rp 4.000.000 - Rp 8.000.000',
                'status' => 'open',
                'posted_by' => $adminId,
                'created_at' => now(),
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'Konser Musik Akhir Tahun',
                'description' => 'Event organizer untuk konser musik akhir tahun kapasitas 5000 orang. Termasuk sound, lighting, dan stage.',
                'sub_role_slug' => 'event_organizer',
                'location' => 'Jakarta',
                'deadline' => '2026-12-20',
                'budget_range' => 'Rp 50.000.000 - Rp 100.000.000',
                'status' => 'open',
                'posted_by' => $adminId,
                'created_at' => now(),
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'Peliputan Kegiatan Pemerintah Daerah',
                'description' => 'Dibutuhkan kreator konten untuk dokumentasi dan publikasi program kegiatan pemerintah daerah.',
                'sub_role_slug' => 'government',
                'location' => 'Yogyakarta',
                'deadline' => '2026-09-10',
                'budget_range' => 'Rp 10.000.000 - Rp 25.000.000',
                'status' => 'open',
                'posted_by' => $adminId,
                'created_at' => now(),
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'Makeup Artist Wedding Premium',
                'description' => 'Dibutuhkan makeup artist profesional untuk pernikahan premium di Bali. Termasuk trial makeup.',
                'sub_role_slug' => 'makeup_artist',
                'location' => 'Bali',
                'deadline' => '2026-07-25',
                'budget_range' => 'Rp 2.500.000 - Rp 4.000.000',
                'status' => 'open',
                'posted_by' => $adminId,
                'created_at' => now(),
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'Videografer Dokumentasi Event',
                'description' => 'Mencari videografer untuk dokumentasi event corporate dan wedding. Portfolio wajib.',
                'sub_role_slug' => 'videographer',
                'location' => 'Jakarta',
                'deadline' => '2026-08-10',
                'budget_range' => 'Rp 5.000.000 - Rp 8.000.000',
                'status' => 'open',
                'posted_by' => $adminId,
                'created_at' => now(),
            ],
            [
                'id' => (string) Str::uuid(),
                'title' => 'Editor Video Konten Sosial',
                'description' => 'Dibutuhkan editor video untuk konten sosial (Instagram, TikTok, YouTube). Style: modern dan dynamic.',
                'sub_role_slug' => 'editor',
                'location' => 'Remote',
                'deadline' => '2026-07-30',
                'budget_range' => 'Rp 1.500.000 - Rp 3.000.000',
                'status' => 'open',
                'posted_by' => $adminId,
                'created_at' => now(),
            ],
        ];

        DB::table('opportunities')->insert($opportunities);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        //
    }
};
