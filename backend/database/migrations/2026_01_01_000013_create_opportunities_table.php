<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('opportunities', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('title', 200);
            $table->text('description')->nullable();
            $table->string('sub_role_slug', 50);
            $table->enum('type', ['location', 'project'])->default('project');
            $table->string('location', 100)->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('location_category', 50)->nullable();
            $table->string('address', 255)->nullable();
            $table->date('deadline')->nullable();
            $table->string('budget_range', 100)->nullable();
            $table->enum('status', ['open', 'closed', 'cancelled', 'under_dispute'])->default('open');
            $table->uuid('posted_by');
            $table->timestamp('created_at')->useCurrent();

            $table->foreign('posted_by')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('opportunities');
    }
};
