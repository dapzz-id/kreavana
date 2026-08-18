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
        Schema::create('job_status_histories', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('job_contract_id');
            $table->uuid('actor_id');
            
            $table->string('transition', 100);
            
            $table->string('from_contract_status', 50)->nullable();
            $table->string('to_contract_status', 50)->nullable();
            $table->string('from_work_status', 50)->nullable();
            $table->string('to_work_status', 50)->nullable();
            
            $table->json('metadata')->nullable();
            
            $table->timestamp('created_at')->useCurrent();
            
            $table->foreign('job_contract_id')->references('id')->on('job_contracts')->onDelete('cascade');
            $table->foreign('actor_id')->references('id')->on('users')->onDelete('cascade');
            
            $table->index('job_contract_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('job_status_histories');
    }
};
