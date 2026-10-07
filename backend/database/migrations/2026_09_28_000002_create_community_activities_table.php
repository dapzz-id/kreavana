<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('community_activities', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('community_id');
            $table->string('title');
            $table->text('description')->nullable();
            $table->timestamp('activity_date')->nullable();
            $table->string('location')->nullable();
            $table->string('status')->default('pending'); // pending, active, completed, cancelled
            $table->integer('max_participants')->nullable();
            $table->uuid('created_by');
            $table->timestamps();

            $table->index(['community_id', 'status']);
            $table->index(['created_by', 'status']);
            $table->index('activity_date');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('community_activities');
    }
};
