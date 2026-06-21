<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Core photos table.
     * original_path  → stored in private storage (only accessible post-purchase).
     * watermarked_path → public-facing version with KREAVANA watermark overlay.
     * is_for_sale    → false means free/portfolio photo, true means purchasable.
     * tags           → comma-separated keywords used by the AI search service.
     */
    public function up(): void
    {
        Schema::create('photos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('original_path');
            $table->string('watermarked_path')->nullable();
            $table->decimal('price', 15, 2)->default(0.00);
            $table->boolean('is_for_sale')->default(false);
            $table->text('tags')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('photos');
    }
};
