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
        Schema::create('media_download_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('buyer_id')->index();
            $table->uuid('purchased_asset_id')->nullable()->index();
            $table->uuid('source_file_id')->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->string('download_type')->default('source_creator'); // 'cloned', 'source_creator'
            $table->timestamps();

            $table->foreign('buyer_id')->references('id')->on('users')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('media_download_logs');
    }
};
