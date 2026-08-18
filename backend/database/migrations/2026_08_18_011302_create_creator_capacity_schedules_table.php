<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('creator_capacity_schedules', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('creator_id');
            $table->date('date');
            $table->unsignedInteger('max_capacity')->nullable();
            $table->boolean('is_unavailable')->default(false);
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->foreign('creator_id')->references('id')->on('users')->onDelete('cascade');
            $table->unique(['creator_id', 'date'], 'creator_date_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('creator_capacity_schedules');
    }
};
