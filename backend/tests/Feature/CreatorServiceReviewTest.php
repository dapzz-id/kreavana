<?php

namespace Tests\Feature;

use App\Enums\RoleType;
use App\Models\CreatorService;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CreatorServiceReviewTest extends TestCase
{
    use RefreshDatabase;

    public function test_eo_package_is_hidden_until_admin_approves_it(): void
    {
        $eo = User::factory()->create([
            'role' => RoleType::Creator,
            'sub_role' => 'event_organizer',
        ]);
        $admin = User::factory()->create(['role' => RoleType::Admin]);
        Storage::fake('public');

        $submission = $this->actingAsApi($eo)->post('/api/creator-services', [
            'title' => 'Paket Corporate',
            'description' => 'Seminar dan gathering hingga 200 peserta.',
            'category' => 'eo_event_package',
            'price' => 35000000,
            'duration_info' => 'Satu hari',
            'thumbnail' => UploadedFile::fake()->create(
                'corporate-package.png',
                100,
                'image/png',
            ),
        ], ['Accept' => 'application/json']);

        $submission->assertCreated()
            ->assertJsonPath('data.status', 'pending');

        $serviceId = $submission->json('data.id');
        $this->assertDatabaseHas('creator_services', [
            'id' => $serviceId,
            'creator_id' => $eo->id,
            'status' => 'pending',
        ]);
        $service = CreatorService::findOrFail($serviceId);
        $this->assertNotNull($service->thumbnail_url);
        $this->assertCount(1, Storage::disk('public')->allFiles('creator_service_thumbnails'));
        $thumbnailPath = parse_url($service->thumbnail_url, PHP_URL_PATH);
        $this->get($thumbnailPath)
            ->assertOk()
            ->assertHeader('Content-Type', 'image/png');

        $this->getJson('/api/creator-services')
            ->assertOk()
            ->assertJsonMissing(['id' => $serviceId]);
        $this->getJson("/api/creator-services/{$serviceId}")->assertNotFound();

        $this->actingAsApi($admin)
            ->getJson('/api/admin/creator-services?status=pending')
            ->assertOk()
            ->assertJsonPath('data.0.id', $serviceId)
            ->assertJsonPath('data.0.thumbnail_url', $service->thumbnail_url);

        $this->actingAsApi($admin)
            ->postJson("/api/admin/creator-services/{$serviceId}/approve")
            ->assertOk()
            ->assertJsonPath('data.status', 'active');

        $this->getJson("/api/creator-services/{$serviceId}")
            ->assertOk()
            ->assertJsonPath('data.status', 'active');
    }

    public function test_only_event_organizers_can_submit_eo_packages(): void
    {
        $creator = User::factory()->create([
            'role' => RoleType::Creator,
            'sub_role' => 'photographer',
        ]);

        $this->actingAsApi($creator)->postJson('/api/creator-services', [
            'title' => 'Paket Event',
            'category' => 'eo_event_package',
            'price' => 1000000,
        ])->assertForbidden();
    }

    public function test_other_creator_package_types_are_pending_and_filterable(): void
    {
        $creator = User::factory()->create([
            'role' => RoleType::Creator,
            'sub_role' => 'videographer',
        ]);
        $admin = User::factory()->create(['role' => RoleType::Admin]);
        Storage::fake('public');

        $submission = $this->actingAsApi($creator)->post(
            '/api/creator-services',
            [
                'title' => 'Paket Video Wedding',
                'description' => 'Dokumentasi video wedding.',
                'category' => 'creator_package',
                'package_type' => 'video_paket',
                'price' => 5000000,
                'thumbnail' => UploadedFile::fake()->create(
                    'video-package.png',
                    100,
                    'image/png',
                ),
            ],
            ['Accept' => 'application/json'],
        );

        $submission->assertCreated()->assertJsonPath('data.status', 'pending');
        $serviceId = $submission->json('data.id');

        $this->actingAsApi($admin)
            ->getJson('/api/admin/creator-services?package_type=video_paket')
            ->assertOk()
            ->assertJsonPath('data.0.id', $serviceId);

        $this->actingAsApi($admin)
            ->getJson('/api/admin/creator-services?package_type=foto_paket')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_admin_rejection_keeps_eo_package_private_and_requires_a_note(): void
    {
        $eo = User::factory()->create([
            'role' => RoleType::Creator,
            'sub_role' => 'event_organizer',
        ]);
        $admin = User::factory()->create(['role' => RoleType::Admin]);
        $service = CreatorService::create([
            'creator_id' => $eo->id,
            'title' => 'Paket Festival',
            'description' => 'Paket festival event.',
            'category' => 'eo_event_package',
            'price' => 75000000,
            'status' => 'pending',
        ]);

        $this->actingAsApi($admin)
            ->postJson("/api/admin/creator-services/{$service->id}/reject", [])
            ->assertUnprocessable();

        $this->postJson("/api/admin/creator-services/{$service->id}/reject", [
            'review_note' => 'Mohon lengkapi rincian fasilitas paket.',
        ])->assertOk()->assertJsonPath('data.status', 'rejected');

        $this->getJson('/api/creator-services')
            ->assertOk()
            ->assertJsonMissing(['id' => $service->id]);
    }
}
