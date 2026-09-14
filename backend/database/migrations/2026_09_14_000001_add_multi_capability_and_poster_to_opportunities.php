<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('opportunities', function (Blueprint $table) {
            $table->string('poster_url', 500)->nullable()->after('description');
            $table->date('event_date')->nullable()->after('deadline');
            $table->time('event_start_time')->nullable()->after('event_date');
            $table->time('event_end_time')->nullable()->after('event_start_time');
        });

        Schema::create('opportunity_requirements', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('opportunity_id');
            $table->string('sub_role_slug', 50);
            $table->unsignedInteger('quantity')->default(1);
            $table->string('notes', 255)->nullable();
            $table->timestamps();

            $table->foreign('opportunity_id')->references('id')->on('opportunities')->cascadeOnDelete();
            $table->index(['opportunity_id', 'sub_role_slug']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('opportunity_requirements');

        Schema::table('opportunities', function (Blueprint $table) {
            $table->dropColumn(['poster_url', 'event_date', 'event_start_time', 'event_end_time']);
        });
    }
};
