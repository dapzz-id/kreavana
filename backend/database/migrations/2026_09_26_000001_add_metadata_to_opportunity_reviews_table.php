<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('opportunity_reviews', function (Blueprint $table) {
            $table->string('reviewer_role', 100)->nullable()->after('comment');
            $table->string('reviewer_company', 150)->nullable()->after('reviewer_role');
            $table->unsignedInteger('helpful_count')->default(0)->after('reviewer_company');
        });
    }

    public function down(): void
    {
        Schema::table('opportunity_reviews', function (Blueprint $table) {
            $table->dropColumn(['reviewer_role', 'reviewer_company', 'helpful_count']);
        });
    }
};
