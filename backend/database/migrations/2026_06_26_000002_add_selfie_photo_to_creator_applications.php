<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('creator_applications', function (Blueprint $table) {
            $table->string('selfie_photo_url', 500)->nullable()->after('ktp_photo_url');
        });
    }

    public function down(): void
    {
        Schema::table('creator_applications', function (Blueprint $table) {
            $table->dropColumn('selfie_photo_url');
        });
    }
};
