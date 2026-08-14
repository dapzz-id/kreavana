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
        Schema::table('opportunities', function (Blueprint $table) {
            $table->boolean('creator_completed')->default(false);
            $table->boolean('buyer_completed')->default(false);
            $table->timestamp('creator_completed_at')->nullable();
        });

        Schema::table('marketplace_purchases', function (Blueprint $table) {
            $table->boolean('creator_completed')->default(false);
            $table->boolean('buyer_completed')->default(false);
            $table->timestamp('creator_completed_at')->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('opportunities', function (Blueprint $table) {
            $table->dropColumn(['creator_completed', 'buyer_completed', 'creator_completed_at']);
        });

        Schema::table('marketplace_purchases', function (Blueprint $table) {
            $table->dropColumn(['creator_completed', 'buyer_completed', 'creator_completed_at']);
        });
    }
};
