<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('community_activity_participants', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('activity_id');
            $table->uuid('user_id');
            $table->string('status')->default('invited'); // invited, confirmed, declined, cancelled
            $table->timestamp('joined_at')->nullable();
            $table->timestamps();

            $table->index(['activity_id', 'status']);
            $table->index(['user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('community_activity_participants');
    }
};
