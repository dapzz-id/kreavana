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
        Schema::create('pihak_categories', function (Blueprint $table) {
            $table->integer('id')->autoIncrement();
            $table->string('slug', 50)->unique();
            $table->string('name', 100);
            $table->text('description')->nullable();
            $table->string('icon', 50)->nullable();
            $table->string('color', 10)->nullable();
        });

        Schema::create('user_pihak', function (Blueprint $table) {
            $table->integer('id')->autoIncrement();
            $table->integer('user_id');
            $table->string('pihak_slug', 50);
            $table->enum('role_type', ['user', 'creator']);
            $table->boolean('is_active')->default(true);
            $table->timestamp('joined_at')->useCurrent();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['user_id', 'pihak_slug', 'role_type'], 'user_pihak_unique');
        });

        Schema::create('opportunities', function (Blueprint $table) {
            $table->integer('id')->autoIncrement();
            $table->string('title', 200);
            $table->text('description')->nullable();
            $table->string('pihak_slug', 50);
            $table->string('location', 100)->nullable();
            $table->date('deadline')->nullable();
            $table->string('budget_range', 100)->nullable();
            $table->enum('status', ['open', 'closed'])->default('open');
            $table->integer('posted_by');
            $table->timestamp('created_at')->useCurrent();

            $table->foreign('posted_by')->references('id')->on('users')->cascadeOnDelete();
        });

        Schema::create('creator_applications', function (Blueprint $table) {
            $table->integer('id')->autoIncrement();
            $table->integer('user_id');
            $table->string('pihak_category', 50);
            $table->text('skill_description');
            $table->string('portfolio_link', 255)->nullable();
            $table->text('experience')->nullable();
            $table->enum('status', ['pending', 'approved', 'rejected'])->default('pending');
            $table->text('admin_note')->nullable();
            $table->timestamp('applied_at')->useCurrent();
            $table->timestamp('reviewed_at')->nullable();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });

        Schema::create('dashboard_stats', function (Blueprint $table) {
            $table->integer('id')->autoIncrement();
            $table->string('pihak_slug', 50);
            $table->enum('role_type', ['user', 'creator']);
            $table->string('stat_label', 100);
            $table->string('stat_value', 100);
            $table->string('stat_icon', 50);
            $table->integer('display_order')->default(0);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('dashboard_stats');
        Schema::dropIfExists('creator_applications');
        Schema::dropIfExists('opportunities');
        Schema::dropIfExists('user_pihak');
        Schema::dropIfExists('pihak_categories');
    }
};
