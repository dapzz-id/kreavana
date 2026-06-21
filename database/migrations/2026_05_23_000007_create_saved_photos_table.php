<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * User bookmarks/saved photos.
     * Composite unique index prevents duplicate saves.
     */
    public function up(): void
    {
        Schema::create('saved_photos', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('photo_id')->constrained('photos')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['user_id', 'photo_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('saved_photos');
    }
};
