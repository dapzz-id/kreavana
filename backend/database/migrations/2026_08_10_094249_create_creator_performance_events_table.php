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
        Schema::create('creator_performance_events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('event_type'); // 'project_rating', 'marketplace_sale'
            $table->string('reference_id'); // e.g. opportunity_review_id, marketplace_purchase_id
            $table->decimal('bonus_percentage', 5, 2);
            $table->timestamps();

            $table->unique(['user_id', 'event_type', 'reference_id'], 'creator_perf_events_unique');
            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('creator_performance_events');
    }
};
