<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('chat_participants', function (Blueprint $table) {
            $table->id();
            $table->foreignId('chat_id')->constrained()->cascadeOnDelete();
            $table->integer('user_id');
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->boolean('is_admin')->default(false);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chat_participants');
    }
};
