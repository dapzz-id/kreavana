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
        Schema::create('message_keys', function (Blueprint $table) {
            $table->uuid('id')->primary();
            
            $table->uuid('message_id');
            $table->foreign('message_id')->references('id')->on('messages')->cascadeOnDelete();
            
            $table->uuid('device_id'); // foreign to user_devices
            $table->foreign('device_id')->references('id')->on('user_devices')->cascadeOnDelete();
            
            $table->text('encrypted_key'); // AES key encrypted with device's RSA public key
            
            $table->timestamps();
            
            $table->unique(['message_id', 'device_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('message_keys');
    }
};
