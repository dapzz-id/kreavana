<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('community_announcements', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('community_id');
            $table->string('title');
            $table->text('content');
            $table->string('type')->default('general'); // general, event, important, warning
            $table->string('priority')->default('normal'); // low, normal, high, urgent
            $table->timestamp('published_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->uuid('created_by');
            $table->string('status')->default('draft'); // draft, published, archived
            $table->timestamps();

            $table->index(['community_id', 'status']);
            $table->index(['created_by', 'status']);
            $table->index('published_at');
            $table->index('expires_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('community_announcements');
    }
};
