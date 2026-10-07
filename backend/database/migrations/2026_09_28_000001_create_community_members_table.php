<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('community_members', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('community_id');
            $table->uuid('user_id');
            $table->string('role')->default('member'); // admin, moderator, member
            $table->string('status')->default('active'); // active, inactive, banned
            $table->timestamp('joined_at')->nullable();
            $table->timestamps();

            $table->index(['community_id', 'status']);
            $table->index(['user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('community_members');
    }
};
