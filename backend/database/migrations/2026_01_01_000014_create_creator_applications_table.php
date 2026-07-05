<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('creator_applications', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('sub_role_slug', 50);
            $table->text('skill_description');
            $table->string('portfolio_link', 255)->nullable();
            $table->text('experience')->nullable();
            $table->string('ktp_photo_url', 500)->nullable();
            $table->string('selfie_photo_url', 500)->nullable();
            $table->string('nik', 16)->nullable();
            $table->string('full_name_ktp', 150)->nullable();
            $table->string('birth_place', 100)->nullable();
            $table->date('birth_date')->nullable();
            $table->text('address_ktp')->nullable();
            $table->enum('status', ['pending', 'approved', 'rejected'])->default('pending');
            $table->text('admin_note')->nullable();
            $table->timestamp('applied_at')->useCurrent();
            $table->timestamp('reviewed_at')->nullable();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('creator_applications');
    }
};
