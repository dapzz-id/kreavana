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
        Schema::table('job_contracts', function (Blueprint $table) {
            $table->dropForeign(['marketplace_item_id']);
            $table->dropColumn('marketplace_item_id');
            $table->uuid('creator_service_id')->nullable()->after('opportunity_id');
            
            $table->foreign('creator_service_id')->references('id')->on('creator_services')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('job_contracts', function (Blueprint $table) {
            $table->dropForeign(['creator_service_id']);
            $table->dropColumn('creator_service_id');
            $table->uuid('marketplace_item_id')->nullable()->after('opportunity_id');
            
            $table->foreign('marketplace_item_id')->references('id')->on('marketplace_items')->nullOnDelete();
        });
    }
};
