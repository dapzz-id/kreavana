<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\User;
use App\Models\JobContract;
use App\Models\LargeTransactionReview;
use App\Enums\RoleType;
use Illuminate\Foundation\Testing\RefreshDatabase;

class LargeTransactionMarketingTest extends TestCase
{
    use RefreshDatabase;

    protected User $client;
    protected User $creator;
    protected User $marketing;
    protected User $regularUser;

    protected function setUp(): void
    {
        parent::setUp();

        $this->client = User::factory()->create(['role' => RoleType::User]);
        $this->creator = User::factory()->create([
            'role' => RoleType::Creator,
            'is_creator_approved' => true,
        ]);
        $this->marketing = User::factory()->create(['role' => RoleType::Marketing]);
        $this->regularUser = User::factory()->create(['role' => RoleType::User]);
    }

    public function test_contract_below_threshold_does_not_create_large_transaction_review()
    {
        $response = $this->actingAsApi($this->client)
            ->postJson('/api/contracts', [
                'my_role' => 'client',
                'partner_id' => $this->creator->id,
                'title' => 'Dokumentasi Acara Mini',
                'agreed_price' => 25000000, // Rp 25M < 100M
                'scheduled_start_date' => now()->addDays(2)->toDateString(),
                'scheduled_end_date' => now()->addDays(3)->toDateString(),
            ]);

        $response->assertStatus(201);
        $contractId = $response->json('data.id');

        $this->assertDatabaseMissing('large_transaction_reviews', [
            'job_contract_id' => $contractId,
        ]);
    }

    public function test_contract_at_or_above_threshold_creates_large_transaction_review()
    {
        $response = $this->actingAsApi($this->client)
            ->postJson('/api/contracts', [
                'my_role' => 'client',
                'partner_id' => $this->creator->id,
                'title' => 'Pengadaan Acara Festival Akbar',
                'agreed_price' => 150000000, // Rp 150M >= 100M
                'scheduled_start_date' => now()->addDays(5)->toDateString(),
                'scheduled_end_date' => now()->addDays(10)->toDateString(),
            ]);

        $response->assertStatus(201);
        $contractId = $response->json('data.id');

        $this->assertDatabaseHas('large_transaction_reviews', [
            'job_contract_id' => $contractId,
            'threshold_amount' => 100000000,
            'contract_amount' => 150000000,
            'status' => 'pending_review',
        ]);
    }

    public function test_marketing_can_assign_verify_and_approve_large_transaction()
    {
        $contract = JobContract::create([
            'client_id' => $this->client->id,
            'creator_id' => $this->creator->id,
            'title' => 'Kontrak Konser Musik',
            'agreed_price' => 200000000,
            'contract_status' => 'draft',
            'work_status' => 'scheduled',
            'scheduled_start_date' => now()->addDays(5)->toDateString(),
            'scheduled_end_date' => now()->addDays(6)->toDateString(),
        ]);

        $review = LargeTransactionReview::create([
            'job_contract_id' => $contract->id,
            'threshold_amount' => 100000000,
            'contract_amount' => 200000000,
            'status' => 'pending_review',
        ]);

        // 1. Assign to marketing
        $resAssign = $this->actingAsApi($this->marketing)
            ->postJson("/api/marketing/transactions/{$review->id}/assign");
        $resAssign->assertStatus(200);

        // 2. Try approve before verification -> should fail 400
        $resEarlyApprove = $this->actingAsApi($this->marketing)
            ->postJson("/api/marketing/transactions/{$review->id}/approve");
        $resEarlyApprove->assertStatus(400);

        // 3. Complete verification meeting and documents
        $resVerify = $this->actingAsApi($this->marketing)
            ->postJson("/api/marketing/transactions/{$review->id}/verify", [
                'verification_notes' => 'Telah dilakukan meeting zoom bersama klien dan vendor. KTP dan NPWP telah dicocokkan.',
                'document_url' => 'https://storage.kreavana.com/documents/contract-verified.pdf',
                'client_verified' => true,
                'creator_verified' => true,
            ]);
        $resVerify->assertStatus(200);

        // 4. Now approve
        $resApprove = $this->actingAsApi($this->marketing)
            ->postJson("/api/marketing/transactions/{$review->id}/approve", [
                'notes' => 'Semua dokumen sah. Transaksi disetujui untuk diproses ke escrow.',
            ]);
        $resApprove->assertStatus(200);

        $review->refresh();
        $this->assertEquals('approved', $review->status);
        $this->assertNotNull($review->approved_at);
    }

    public function test_non_marketing_cannot_access_marketing_endpoints()
    {
        $res = $this->actingAsApi($this->regularUser)
            ->getJson('/api/marketing/transactions');

        $res->assertStatus(403);
    }
}
