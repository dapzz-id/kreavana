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
        Schema::create('purchased_storage_assets', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('buyer_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('order_id')->constrained('marketplace_purchases')->cascadeOnDelete();
            $table->foreignUuid('marketplace_asset_id')->constrained('marketplace_items')->cascadeOnDelete();
            $table->foreignUuid('source_storage_file_id')->constrained('storage_files')->cascadeOnDelete();
            $table->uuid('cloned_storage_file_id')->nullable();
            $table->string('status')->default('pending_storage'); // cloned, pending_storage, failed
            $table->integer('clone_attempts')->default(0);
            $table->timestamp('last_clone_attempt_at')->nullable();
            $table->timestamps();

            $table->unique(['order_id', 'source_storage_file_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('purchased_storage_assets');
    }
};
