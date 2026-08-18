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
        Schema::table('marketplace_items', function (Blueprint $table) {
            $table->enum('status', ['draft', 'published', 'archived'])->default('draft')->after('is_active');
            $table->enum('delivery_type', ['digital_download', 'service'])->default('digital_download')->after('type');
            $table->string('duration_info')->nullable()->after('price');
        });

        // Backfill status based on is_active
        DB::table('marketplace_items')->where('is_active', true)->update(['status' => 'published']);
        DB::table('marketplace_items')->where('is_active', false)->update(['status' => 'draft']);

        Schema::table('job_contracts', function (Blueprint $table) {
            $table->uuid('marketplace_item_id')->nullable()->after('opportunity_id');
            $table->foreign('marketplace_item_id')->references('id')->on('marketplace_items')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('job_contracts', function (Blueprint $table) {
            $table->dropForeign(['marketplace_item_id']);
            $table->dropColumn('marketplace_item_id');
        });

        Schema::table('marketplace_items', function (Blueprint $table) {
            $table->dropColumn(['status', 'delivery_type', 'duration_info']);
        });
    }
};
