<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('large_transaction_reviews', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('job_contract_id');
            $table->decimal('threshold_amount', 15, 2);
            $table->decimal('contract_amount', 15, 2);
            $table->uuid('assigned_marketing_id')->nullable();
            $table->enum('status', [
                'pending_review',
                'assigned',
                'meeting_scheduled',
                'document_verified',
                'approved',
                'rejected'
            ])->default('pending_review');
            $table->text('verification_notes')->nullable();
            $table->string('document_url', 500)->nullable();
            $table->timestamp('client_verified_at')->nullable();
            $table->timestamp('creator_verified_at')->nullable();
            $table->timestamp('approved_at')->nullable();
            $table->timestamps();

            $table->foreign('job_contract_id')->references('id')->on('job_contracts')->cascadeOnDelete();
            $table->foreign('assigned_marketing_id')->references('id')->on('users')->nullOnDelete();

            $table->index(['job_contract_id', 'status']);
            $table->index(['assigned_marketing_id', 'status']);
        });

        Schema::table('portfolio_items', function (Blueprint $table) {
            $table->date('event_date')->nullable()->after('description');
            $table->string('location', 150)->nullable()->after('event_date');
            $table->enum('source', ['external', 'internal'])->default('external')->after('location');
            $table->enum('verification_status', ['self_reported', 'verified', 'unverified'])->default('self_reported')->after('source');
            $table->string('client_name', 150)->nullable()->after('verification_status');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->string('role', 20)->default('user')->change();
        });
    }

    public function down(): void
    {
        Schema::table('portfolio_items', function (Blueprint $table) {
            $table->dropColumn(['event_date', 'location', 'source', 'verification_status', 'client_name']);
        });

        Schema::dropIfExists('large_transaction_reviews');
    }
};
