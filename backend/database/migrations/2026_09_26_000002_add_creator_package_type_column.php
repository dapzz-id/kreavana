<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn('creator_services', 'package_type')) {
            Schema::table('creator_services', function (Blueprint $table) {
                $table->string('package_type', 100)->nullable()->after('thumbnail_url');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('creator_services', 'package_type')) {
            Schema::table('creator_services', function (Blueprint $table) {
                $table->dropColumn('package_type');
            });
        }
    }
};
