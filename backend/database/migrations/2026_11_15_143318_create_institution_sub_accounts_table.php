<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if (!Schema::hasTable('institution_sub_accounts')) {
            Schema::create('institution_sub_accounts', function (Blueprint $table) {
                $table->uuid('id')->primary();
                $table->uuid('user_id')->unique();
                $table->uuid('institution_id');
                $table->uuid('institution_resource_id')->nullable();
                $table->string('password_hash');
                $table->boolean('is_active')->default(true);
                $table->timestamp('password_changed_at')->nullable();
                $table->timestamps();

                $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
                $table->foreign('institution_id')->references('id')->on('users')->cascadeOnDelete();
                $table->foreign('institution_resource_id')->references('id')->on('institution_resources')->nullOnDelete();
                $table->index(['institution_id', 'is_active']);
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('institution_sub_accounts');
    }
};
