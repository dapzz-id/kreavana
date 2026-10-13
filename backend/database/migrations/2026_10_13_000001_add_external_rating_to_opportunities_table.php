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
            $table->decimal('external_rating', 3, 2)->nullable()->after('budget_range');
            $table->string('external_rating_source', 100)->nullable()->after('external_rating');
            $table->string('external_proof_url', 500)->nullable()->after('external_rating_source');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('opportunities', function (Blueprint $table) {
            $table->dropColumn(['external_rating', 'external_rating_source', 'external_proof_url']);
        });
    }
};
