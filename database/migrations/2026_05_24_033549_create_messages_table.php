<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sender_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('receiver_id')->constrained('users')->onDelete('cascade');
            $table->text('body')->nullable();
            $table->string('attachment_path')->nullable();    // optional image/file
            $table->enum('attachment_type', ['image', 'video', 'file'])->nullable();
            $table->timestamp('read_at')->nullable();         // null = unread
            $table->timestamps();

            $table->index(['sender_id', 'receiver_id']);
            $table->index('read_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('messages');
    }
};
