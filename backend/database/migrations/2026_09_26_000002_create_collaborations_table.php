<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('collaborations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('requester_id');
            $table->string('project_title', 200);
            $table->text('description')->nullable();
            $table->string('project_location', 200)->nullable();
            $table->enum('status', ['pending', 'accepted', 'rejected', 'active', 'completed', 'cancelled'])->default('pending');
            $table->date('start_date')->nullable();
            $table->date('end_date')->nullable();
            $table->decimal('budget_min', 15, 2)->nullable();
            $table->decimal('budget_max', 15, 2)->nullable();
            $table->text('notes')->nullable();
            $table->text('reject_reason')->nullable();
            $table->timestamp('responded_at')->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->timestamp('updated_at')->useCurrent()->useCurrentOnUpdate();

            $table->foreign('requester_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['requester_id', 'status']);
            $table->index(['status', 'created_at']);
        });

        Schema::create('collaboration_members', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('collaboration_id');
            $table->uuid('user_id');
            $table->string('role', 100)->nullable();
            $table->enum('status', ['invited', 'accepted', 'rejected', 'active', 'left'])->default('invited');
            $table->timestamp('joined_at')->nullable();
            $table->timestamp('responded_at')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->foreign('collaboration_id')->references('id')->on('collaborations')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['collaboration_id', 'user_id']);
            $table->index(['user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('collaboration_members');
        Schema::dropIfExists('collaborations');
    }
};
