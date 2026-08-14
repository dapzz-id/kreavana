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
        Schema::create('marketplace_item_media', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('marketplace_item_id')->constrained()->cascadeOnDelete();
            $table->string('file_path');
            $table->string('watermarked_file_path')->nullable();
            $table->enum('file_type', ['image', 'video'])->default('image');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('marketplace_item_media');
    }
};
