<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('opportunity_applications', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('opportunity_id');
            $table->uuid('creator_id');
            $table->string('sub_role_slug', 50);
            $table->text('pitch_message');
            $table->text('questions_notes')->nullable();
            $table->decimal('bid_price', 15, 2)->nullable();
            $table->enum('status', ['pending', 'approved', 'rejected', 'withdrawn', 'cancelled'])->default('pending');
            $table->string('rejection_reason', 500)->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamps();

            $table->foreign('opportunity_id')->references('id')->on('opportunities')->cascadeOnDelete();
            $table->foreign('creator_id')->references('id')->on('users')->cascadeOnDelete();

            $table->unique(['opportunity_id', 'creator_id', 'sub_role_slug'], 'opp_app_unique');
            $table->index(['opportunity_id', 'status']);
            $table->index(['creator_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('opportunity_applications');
    }
};
