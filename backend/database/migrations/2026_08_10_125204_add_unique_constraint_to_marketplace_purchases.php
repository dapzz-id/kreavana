<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('marketplace_purchases', function (Blueprint $table) {
            $table->unique(['user_id', 'marketplace_item_id'], 'user_item_unique');
        });
    }

    public function down(): void
    {
        Schema::table('marketplace_purchases', function (Blueprint $table) {
            $table->dropUnique('user_item_unique');
        });
    }
};
