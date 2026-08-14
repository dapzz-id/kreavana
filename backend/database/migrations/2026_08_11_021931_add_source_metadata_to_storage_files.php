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
        Schema::table('storage_files', function (Blueprint $table) {
            $table->string('source_type')->default('creator_upload')->after('category');
            $table->uuid('source_storage_file_id')->nullable()->after('source_type');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('storage_files', function (Blueprint $table) {
            $table->dropColumn(['source_type', 'source_storage_file_id']);
        });
    }
};
