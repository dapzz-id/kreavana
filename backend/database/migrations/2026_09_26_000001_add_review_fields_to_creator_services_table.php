<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('creator_services', function (Blueprint $table) {
            $table->uuid('reviewed_by')->nullable()->after('status');
            $table->timestamp('reviewed_at')->nullable()->after('reviewed_by');
            $table->text('review_note')->nullable()->after('reviewed_at');
            $table->string('thumbnail_url')->nullable()->after('review_note');
            $table->string('package_type', 100)->nullable()->after('thumbnail_url');
            $table->foreign('reviewed_by')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('creator_services', function (Blueprint $table) {
            $table->dropForeign(['reviewed_by']);
            $table->dropColumn([
                'reviewed_by',
                'reviewed_at',
                'review_note',
                'thumbnail_url',
                'package_type',
            ]);
        });
    }
};
