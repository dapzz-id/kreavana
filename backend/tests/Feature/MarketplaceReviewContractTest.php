<?php

namespace Tests\Feature;

use App\Models\MarketplaceItem;
use App\Models\MarketplacePurchase;
use App\Models\MarketplaceReview;
use App\Models\User;
use App\Models\JobContract;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MarketplaceReviewContractTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
    }

    private function createUser()
    {
        $user = new User();
        $user->name = 'Test User';
        $user->email = 'test' . rand() . '@example.com';
        $user->password = bcrypt('password');
        $user->username = 'testuser' . rand();
        $user->role = 'user';
        $user->sub_role = 'general';
        $user->save();
        return $user;
    }

    private function createItem($userId, $type)
    {
        $item = new MarketplaceItem();
        $item->user_id = $userId;
        $item->title = 'Test Item';
        $item->category = 'Lainnya';
        $item->type = $type;
        $item->price = 10000;
        $item->is_active = true;
        $item->status = 'published';
        $item->save();
        return $item;
    }

    private function createPurchase($userId, $itemId, $status)
    {
        $purchase = new MarketplacePurchase();
        $purchase->user_id = $userId;
        $purchase->marketplace_item_id = $itemId;
        $purchase->status = $status;
        $purchase->amount = 10000;
        $purchase->save();
        return $purchase;
    }

    private function createReview($userId, $itemId)
    {
        $review = new MarketplaceReview();
        $review->user_id = $userId;
        $review->marketplace_item_id = $itemId;
        $review->rating = 5;
        $review->comment = 'Bagus';
        $review->save();
        return $review;
    }

    public function test_paid_item_no_purchase_cannot_review()
    {
        $user = $this->createUser();
        $item = $this->createItem($user->id, 'paid');

        $response = $this->actingAs($user, 'api')->getJson("/api/marketplace/{$item->id}");

        $response->assertStatus(200)
                 ->assertJsonPath('data.has_purchased', false)
                 ->assertJsonPath('data.has_reviewed', false)
                 ->assertJsonPath('data.can_review', false);
    }

    public function test_paid_item_successful_purchase_can_review()
    {
        $user = $this->createUser();
        $item = $this->createItem($user->id, 'paid');
        $this->createPurchase($user->id, $item->id, 'success');

        $response = $this->actingAs($user, 'api')->getJson("/api/marketplace/{$item->id}");

        $response->assertStatus(200)
                 ->assertJsonPath('data.has_purchased', true)
                 ->assertJsonPath('data.can_review', true);
    }

    public function test_paid_item_pending_purchase_cannot_review()
    {
        $user = $this->createUser();
        $item = $this->createItem($user->id, 'paid');
        $this->createPurchase($user->id, $item->id, 'pending');

        $response = $this->actingAs($user, 'api')->getJson("/api/marketplace/{$item->id}");

        $response->assertStatus(200)
                 ->assertJsonPath('data.has_purchased', false)
                 ->assertJsonPath('data.can_review', false);
    }

    public function test_paid_item_successful_purchase_with_existing_review()
    {
        $user = $this->createUser();
        $item = $this->createItem($user->id, 'paid');
        $this->createPurchase($user->id, $item->id, 'success');
        $this->createReview($user->id, $item->id);

        $response = $this->actingAs($user, 'api')->getJson("/api/marketplace/{$item->id}");

        $response->assertStatus(200)
                 ->assertJsonPath('data.has_reviewed', true)
                 ->assertJsonPath('data.can_review', true);
    }

    public function test_free_item_authenticated_user_can_review()
    {
        $user = $this->createUser();
        $item = $this->createItem($user->id, 'free');

        $response = $this->actingAs($user, 'api')->getJson("/api/marketplace/{$item->id}");

        $response->assertStatus(200)
                 ->assertJsonPath('data.has_purchased', false)
                 ->assertJsonPath('data.can_review', true);
    }

    public function test_unauthenticated_user_cannot_review()
    {
        $creator = $this->createUser();
        $item = $this->createItem($creator->id, 'free');

        $response = $this->getJson("/api/marketplace/{$item->id}");

        $response->assertStatus(200)
                 ->assertJsonPath('data.has_purchased', false)
                 ->assertJsonPath('data.has_reviewed', false)
                 ->assertJsonPath('data.can_review', false);
    }

    public function test_different_buyer_cannot_use_others_purchase()
    {
        $creator = $this->createUser();
        $buyer = $this->createUser();
        $otherUser = $this->createUser();
        $item = $this->createItem($creator->id, 'paid');
        
        $this->createPurchase($buyer->id, $item->id, 'success');

        $response = $this->actingAs($otherUser, 'api')->getJson("/api/marketplace/{$item->id}");

        $response->assertStatus(200)
                 ->assertJsonPath('data.has_purchased', false)
                 ->assertJsonPath('data.can_review', false);
    }

    public function test_job_contract_without_marketplace_purchase_does_not_grant_eligibility()
    {
        $user = $this->createUser();
        $creator = $this->createUser();
        $item = $this->createItem($creator->id, 'paid');
        
        $contract = new JobContract();
        $contract->client_id = $user->id;
        $contract->creator_id = $creator->id;
        $contract->title = 'Test';
        $contract->contract_status = 'completed';
        $contract->save();

        $response = $this->actingAs($user, 'api')->getJson("/api/marketplace/{$item->id}");

        $response->assertStatus(200)
                 ->assertJsonPath('data.has_purchased', false)
                 ->assertJsonPath('data.can_review', false);
    }
}
