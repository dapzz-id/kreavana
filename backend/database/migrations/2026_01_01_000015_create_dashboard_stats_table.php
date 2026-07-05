<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('dashboard_stats', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('sub_role_slug', 50);
            $table->enum('role_type', ['user', 'creator']);
            $table->string('stat_label', 100);
            $table->string('stat_value', 100);
            $table->string('stat_icon', 50);
            $table->integer('display_order')->default(0);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dashboard_stats');
    }
};
