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
        Schema::table('marketplace_purchases', function (Blueprint $table) {
            $table->string('storage_sync_status')->default('pending')->after('status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('marketplace_purchases', function (Blueprint $table) {
            $table->dropColumn('storage_sync_status');
        });
    }
};
