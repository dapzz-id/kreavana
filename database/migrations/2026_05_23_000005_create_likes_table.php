<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Pivot table for user likes on photos.
     * Composite unique index prevents a user from liking the same photo twice.
     */
    public function up(): void
    {
        Schema::create('likes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('photo_id')->constrained('photos')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['user_id', 'photo_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('likes');
    }
};
