<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_sub_roles', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('sub_role_slug', 50);
            $table->enum('role_type', ['user', 'creator']);
            $table->boolean('is_active')->default(true);
            $table->timestamp('joined_at')->useCurrent();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['user_id', 'sub_role_slug', 'role_type'], 'user_sub_roles_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_sub_roles');
    }
};
