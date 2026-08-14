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
        Schema::create('file_deletion_logs', function (Blueprint $table) {
            $table->id();
            $table->uuid('storage_file_id');
            $table->foreignUuid('deleted_by')->constrained('users')->onDelete('cascade');
            $table->string('reason')->nullable();
            $table->string('ip_address')->nullable();
            $table->string('user_agent')->nullable();
            $table->string('category')->nullable();
            $table->unsignedBigInteger('file_size')->default(0);
            $table->timestamps();
            
            $table->index(['storage_file_id', 'deleted_by']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('file_deletion_logs');
    }
};
