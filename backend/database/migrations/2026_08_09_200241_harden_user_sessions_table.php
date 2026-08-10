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
        // 1. Modify the existing user_sessions table
        Schema::table('user_sessions', function (Blueprint $table) {
            // Drop old columns that are no longer used securely
            $table->dropUnique(['session_token']);
            $table->dropUnique(['refresh_token']);
            $table->dropColumn(['session_token', 'refresh_token']);

            // Add new device tracking and revocation columns
            $table->string('device_id')->nullable()->after('user_id');
            $table->string('device_name')->nullable()->after('device_id');
            $table->string('platform')->nullable()->after('device_name');
            $table->string('ip_address', 45)->nullable()->after('platform');
            $table->text('user_agent')->nullable()->after('ip_address');
            $table->timestamp('revoked_at')->nullable()->after('user_agent');
            $table->timestamp('last_used_at')->nullable()->after('expires_at');
        });

        // 2. Create the new refresh_tokens table for atomic rotation
        Schema::create('refresh_tokens', function (Blueprint $table) {
            // The selector serves as the primary key
            $table->uuid('id')->primary(); 
            
            $table->uuid('user_session_id');
            $table->foreign('user_session_id')
                  ->references('id')
                  ->on('user_sessions')
                  ->onDelete('cascade');

            // SHA-256 hash of the secret portion of the token
            $table->string('token_hash', 64)->unique();
            
            $table->boolean('is_active')->default(true);
            $table->timestamp('expires_at');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('refresh_tokens');

        Schema::table('user_sessions', function (Blueprint $table) {
            $table->dropColumn([
                'device_id', 
                'device_name', 
                'platform', 
                'ip_address', 
                'user_agent', 
                'revoked_at', 
                'last_used_at'
            ]);
            $table->string('session_token', 100)->unique()->after('user_id');
            $table->string('refresh_token', 100)->unique()->after('session_token');
        });
    }
};
