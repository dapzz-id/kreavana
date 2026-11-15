<?php

namespace Tests\Feature;

use App\Models\Opportunity;
use App\Models\Subscription;
use App\Models\User;
use App\Models\UserAddress;
use App\Services\AiService;
use Exception;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Mockery;
use Tests\TestCase;
use Tymon\JWTAuth\Facades\JWTAuth;

class AiRecommendationTest extends TestCase
{
    use RefreshDatabase;

    private function authHeadersFor(User $user): array
    {
        $token = JWTAuth::fromUser($user);

        return [
            'Authorization' => "Bearer {$token}",
        ];
    }

    private function grantProSubscription(User $user): void
    {
        Subscription::create([
            'user_id' => $user->id,
            'tier' => 'pro',
            'price_paid' => 199999,
            'auto_renew' => true,
            'expires_at' => now()->addYear(),
        ]);
    }

    private function attachAddress(User $user, string $city, string $province = 'DKI Jakarta'): UserAddress
    {
        return UserAddress::create([
            'user_id' => $user->id,
            'label' => 'Kantor Utama',
            'recipient_name' => $user->name,
            'phone' => '081234567890',
            'address' => "Jl. Sudirman No. 1, {$city}",
            'city' => $city,
            'province' => $province,
            'postal_code' => '12190',
            'is_default' => true,
        ]);
    }

    public function test_guest_cannot_access_ai_recommendations(): void
    {
        $this->postJson('/api/ai/recommendations', [
            'role' => 'creator',
            'niche' => 'Fotografi',
            'sub_role' => 'all',
            'location' => 'Lokasi Sekarang',
        ])->assertStatus(401);
    }

    public function test_free_user_receives_pro_subscription_required_error(): void
    {
        $user = User::factory()->create(['role' => 'creator']);

        $response = $this->withHeaders($this->authHeadersFor($user))
            ->postJson('/api/ai/recommendations', [
                'role' => 'creator',
                'niche' => 'Fotografi',
                'sub_role' => 'all',
                'location' => 'Lokasi Sekarang',
            ]);

        $response->assertStatus(403)
            ->assertJson([
                'status' => false,
                'error_code' => 'pro_subscription_required',
            ]);
    }

    public function test_pro_user_all_sub_role_and_current_location_matches_jabodetabek_db_records(): void
    {
        Http::fake([
            '*' => Http::response(['error' => ['message' => 'Simulated offline']], 503),
        ]);

        $requester = User::factory()->create(['role' => 'user', 'name' => 'Peminta Rekomendasi']);
        $this->grantProSubscription($requester);

        $jakartaCreator = User::factory()->create([
            'role' => 'creator',
            'sub_role' => 'photographer',
            'is_creator_approved' => true,
            'name' => 'Studio Lensa Jakarta',
        ]);
        $this->attachAddress($jakartaCreator, 'Jakarta Selatan', 'DKI Jakarta');

        $surabayaCreator = User::factory()->create([
            'role' => 'creator',
            'sub_role' => 'photographer',
            'is_creator_approved' => true,
            'name' => 'Studio Lensa Surabaya',
        ]);
        $this->attachAddress($surabayaCreator, 'Surabaya', 'Jawa Timur');

        $corporatePoster = User::factory()->create([
            'role' => 'user',
            'sub_role' => 'corporate',
            'name' => 'PT Nusantara Media',
        ]);
        $tangerangOpportunity = Opportunity::factory()->create([
            'posted_by' => $corporatePoster->id,
            'title' => 'Kampanye Visual Produk Q4 Tangerang',
            'sub_role_slug' => 'photographer',
            'location' => 'Tangerang',
            'status' => 'open',
        ]);

        $response = $this->withHeaders($this->authHeadersFor($requester))
            ->postJson('/api/ai/recommendations', [
                'role' => 'user',
                'niche' => 'Kreatif',
                'sub_role' => 'all',
                'location' => 'Lokasi Sekarang',
            ]);

        $response->assertStatus(200)
            ->assertJsonPath('status', true)
            ->assertJsonStructure([
                'status',
                'message',
                'data' => [
                    'summary',
                    'recommendations' => [
                        '*' => ['title', 'category', 'reason', 'impact', 'match_score', 'action_label'],
                    ],
                    'matched_items',
                    'ai_provider',
                ],
            ]);

        $matchedIds = collect($response->json('data.matched_items'))->pluck('id')->all();
        $this->assertContains($jakartaCreator->id, $matchedIds);
        $this->assertContains($tangerangOpportunity->id, $matchedIds);
        $this->assertNotContains($surabayaCreator->id, $matchedIds);
    }

    public function test_pro_user_corporate_sub_role_matches_corporate_users_and_open_opportunities(): void
    {
        Http::fake([
            '*' => Http::response(['error' => ['message' => 'Simulated offline']], 503),
        ]);

        $creator = User::factory()->create([
            'role' => 'creator',
            'sub_role' => 'videographer',
            'is_creator_approved' => true,
            'name' => 'Kreator Videografi',
        ]);
        $this->grantProSubscription($creator);

        $corporateActive = User::factory()->create([
            'role' => 'user',
            'sub_role' => 'corporate',
            'name' => 'PT Kreasi Korporat Indonesia',
            'is_suspended' => false,
        ]);
        $this->attachAddress($corporateActive, 'Jakarta Pusat', 'DKI Jakarta');

        $corporateSuspended = User::factory()->create([
            'role' => 'user',
            'sub_role' => 'corporate',
            'name' => 'PT Ditangguhkan',
            'is_suspended' => true,
        ]);
        $this->attachAddress($corporateSuspended, 'Jakarta Barat', 'DKI Jakarta');

        $regularUser = User::factory()->create([
            'role' => 'user',
            'sub_role' => null,
            'name' => 'Pengguna Individu Biasa',
        ]);
        $this->attachAddress($regularUser, 'Jakarta Selatan', 'DKI Jakarta');

        $openCorporateOpportunity = Opportunity::factory()->create([
            'posted_by' => $corporateActive->id,
            'title' => 'Produksi Company Profile Tahunan',
            'sub_role_slug' => 'videographer',
            'location' => 'Jakarta',
            'status' => 'open',
        ]);

        $response = $this->withHeaders($this->authHeadersFor($creator))
            ->postJson('/api/ai/recommendations', [
                'role' => 'creator',
                'niche' => 'Produksi Video',
                'sub_role' => 'corporate',
                'location' => 'Jakarta',
            ]);

        $response->assertStatus(200)
            ->assertJsonPath('status', true);

        $matchedItems = collect($response->json('data.matched_items'));
        $matchedIds = $matchedItems->pluck('id')->all();

        $this->assertContains($corporateActive->id, $matchedIds);
        $this->assertContains($openCorporateOpportunity->id, $matchedIds);
        $this->assertNotContains($corporateSuspended->id, $matchedIds);
        $this->assertNotContains($regularUser->id, $matchedIds);
    }

    public function test_pro_user_photographer_all_indonesia_and_school_institution_matching(): void
    {
        Http::fake([
            '*' => Http::response(['error' => ['message' => 'Simulated offline']], 503),
        ]);

        $requester = User::factory()->create(['role' => 'user', 'name' => 'Pencari Talenta']);
        $this->grantProSubscription($requester);

        $photographer = User::factory()->create([
            'role' => 'creator',
            'sub_role' => 'photographer',
            'is_creator_approved' => true,
            'name' => 'Bandung Frame Studio',
        ]);
        $this->attachAddress($photographer, 'Bandung', 'Jawa Barat');

        $videographer = User::factory()->create([
            'role' => 'creator',
            'sub_role' => 'videographer',
            'is_creator_approved' => true,
            'name' => 'Bandung Motion Pictures',
        ]);
        $this->attachAddress($videographer, 'Bandung', 'Jawa Barat');

        $school = User::factory()->create([
            'role' => 'creator',
            'sub_role' => 'institution',
            'is_creator_approved' => true,
            'name' => 'SMK Telekomunikasi Telesandi Bekasi',
        ]);
        $this->attachAddress($school, 'Bekasi', 'Jawa Barat');

        // 'Seluruh Indonesia' + 'photographer' should match Bandung photographer without rejecting by nationwide string
        $photoResponse = $this->withHeaders($this->authHeadersFor($requester))
            ->postJson('/api/ai/recommendations', [
                'role' => 'user',
                'niche' => 'Fotografi',
                'sub_role' => 'photographer',
                'location' => 'Seluruh Indonesia',
            ]);

        $photoResponse->assertStatus(200)
            ->assertJsonPath('status', true);

        $photoIds = collect($photoResponse->json('data.matched_items'))->pluck('id')->all();
        $this->assertContains($photographer->id, $photoIds);
        $this->assertNotContains($videographer->id, $photoIds);

        // 'school' sub_role should resolve to 'institution' creators
        $schoolResponse = $this->withHeaders($this->authHeadersFor($requester))
            ->postJson('/api/ai/recommendations', [
                'role' => 'user',
                'niche' => 'Edukasi',
                'sub_role' => 'school',
                'location' => 'Bekasi',
            ]);

        $schoolResponse->assertStatus(200)
            ->assertJsonPath('status', true);

        $schoolIds = collect($schoolResponse->json('data.matched_items'))->pluck('id')->all();
        $this->assertContains($school->id, $schoolIds);
    }

    public function test_ai_recommendations_does_not_leak_raw_exception_details_on_failure(): void
    {
        $user = User::factory()->create(['role' => 'creator']);
        $this->grantProSubscription($user);

        $mockAiService = Mockery::mock(AiService::class);
        $mockAiService->shouldReceive('getRecommendations')
            ->once()
            ->andThrow(new Exception("SQLSTATE[42S22]: Column not found: 1054 Unknown column 'location'"));
        $this->app->instance(AiService::class, $mockAiService);

        $response = $this->withHeaders($this->authHeadersFor($user))
            ->postJson('/api/ai/recommendations', [
                'role' => 'creator',
                'niche' => 'Fotografi',
                'sub_role' => 'all',
                'location' => 'Lokasi Sekarang',
            ]);

        $response->assertStatus(500)
            ->assertJson([
                'status' => false,
                'message' => 'Gagal memproses rekomendasi AI saat ini. Silakan coba beberapa saat lagi.',
            ]);

        $this->assertStringNotContainsString('SQLSTATE', (string) $response->json('message'));
    }
}
