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
        Schema::create('job_contracts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('client_id');
            $table->uuid('creator_id');
            $table->uuid('opportunity_id')->nullable();
            
            $table->string('title', 200);
            $table->text('description')->nullable();
            $table->text('terms')->nullable();
            
            $table->decimal('agreed_price', 15, 2)->default(0.00);
            $table->decimal('escrow_amount', 15, 2)->default(0.00);
            
            $table->string('contract_status', 50)->default('draft');
            $table->string('work_status', 50)->default('scheduled');
            
            $table->date('deadline')->nullable();
            
            $table->boolean('creator_approved')->default(false);
            $table->boolean('client_approved')->default(false);
            
            $table->string('dispute_group_id', 100)->nullable();
            $table->text('cancel_reason')->nullable();
            
            $table->timestamp('scheduled_at')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            
            $table->timestamps();

            $table->foreign('client_id')->references('id')->on('users');
            $table->foreign('creator_id')->references('id')->on('users');
            $table->foreign('opportunity_id')->references('id')->on('opportunities')->nullOnDelete();
            
            $table->index('client_id');
            $table->index('creator_id');
            $table->index('contract_status');
            $table->index('work_status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('job_contracts');
    }
};
