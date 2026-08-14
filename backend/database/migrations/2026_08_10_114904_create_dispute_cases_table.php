<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('dispute_cases', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->enum('case_type', ['marketplace_refund', 'opportunity_cancellation']);
            $table->uuid('requester_id');
            $table->uuid('other_party_id');
            $table->uuid('assigned_admin_id');
            $table->uuid('marketplace_purchase_id')->nullable();
            $table->uuid('opportunity_id')->nullable();
            $table->uuid('chat_id')->nullable();
            $table->text('reason');
            $table->enum('status', ['pending', 'under_review', 'approved', 'rejected', 'resolved', 'awaiting_settlement', 'refunded'])->default('pending');
            $table->text('resolution')->nullable();
            $table->timestamps();
            
            // Unique constraints to prevent duplicate active cases
            // (Only one active refund per purchase, or one active cancellation per opportunity)
            // We can't use a simple unique constraint if there can be rejected ones and then new ones.
            // But for simplicity, we'll enforce unique per transaction at the application level and db level if possible.
            // Actually, we can just let application level handle the 'active' part and db level can have an index.
            $table->index(['marketplace_purchase_id', 'status']);
            $table->index(['opportunity_id', 'status']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('dispute_cases');
    }
};
