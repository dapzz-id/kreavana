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
        Schema::create('opportunity_reviews', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('opportunity_id');
            $table->uuid('reviewer_id');
            $table->uuid('creator_id');
            $table->decimal('rating', 3, 2);
            $table->text('comment')->nullable();
            $table->timestamps();

            // Enforce one review per opportunity per reviewer for a creator
            $table->unique(['opportunity_id', 'reviewer_id', 'creator_id'], 'opp_review_unique');
            
            $table->foreign('opportunity_id')->references('id')->on('opportunities')->onDelete('cascade');
            $table->foreign('reviewer_id')->references('id')->on('users')->onDelete('cascade');
            $table->foreign('creator_id')->references('id')->on('users')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('opportunity_reviews');
    }
};
