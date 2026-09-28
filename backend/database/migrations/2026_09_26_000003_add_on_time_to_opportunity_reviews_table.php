<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('opportunity_reviews', function (Blueprint $table) {
            $table->boolean('is_on_time')->nullable()->after('rating');
            $table->unsignedInteger('delivery_days')->nullable()->after('is_on_time');
        });
    }

    public function down(): void
    {
        Schema::table('opportunity_reviews', function (Blueprint $table) {
            $table->dropColumn(['is_on_time', 'delivery_days']);
        });
    }
};
