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
            $table->string('official_acceptance_letter_url', 500)->nullable()->after('wet_signature_verified_at');
            $table->string('official_acceptance_letter_name', 255)->nullable()->after('official_acceptance_letter_url');
            $table->timestamp('official_acceptance_letter_uploaded_at')->nullable()->after('official_acceptance_letter_name');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('opportunities', function (Blueprint $table) {
            $table->dropColumn([
                'official_acceptance_letter_url',
                'official_acceptance_letter_name',
                'official_acceptance_letter_uploaded_at',
            ]);
        });
    }
};
