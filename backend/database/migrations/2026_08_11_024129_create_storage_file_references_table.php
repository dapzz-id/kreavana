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
        Schema::create('storage_file_references', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('storage_file_id')->index();
            $table->string('owner_type'); // 'user', 'system', etc.
            $table->uuid('owner_id'); // buyer_id or creator_id
            $table->string('reference_type'); // 'marketplace_purchase', 'creator_upload'
            $table->uuid('reference_id')->nullable(); // order_id or marketplace_item_id
            $table->timestamps();

            $table->foreign('storage_file_id')->references('id')->on('storage_files')->onDelete('cascade');
            $table->foreign('owner_id')->references('id')->on('users')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('storage_file_references');
    }
};
