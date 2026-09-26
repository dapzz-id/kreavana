<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('institution_resources', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('resource_type', 40);
            $table->string('title', 200);
            $table->text('description')->nullable();
            $table->string('status', 30)->default('draft');
            $table->json('metadata')->nullable();
            $table->timestamp('published_at')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['user_id', 'resource_type']);
            $table->index(['resource_type', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('institution_resources');
    }
};
