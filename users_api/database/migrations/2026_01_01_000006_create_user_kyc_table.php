<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_kyc', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id')->unique();
            $table->string('nik', 30)->nullable()->unique();
            $table->string('full_name_ktp')->nullable();
            $table->string('ktp_photo_url', 500)->nullable();
            $table->string('selfie_photo_url', 500)->nullable();
            $table->string('nib_number', 50)->nullable();
            $table->string('nib_file_url', 500)->nullable();
            $table->string('verification_type')->default('individual'); // individual, business
            $table->enum('status', ['unverified', 'pending', 'approved', 'rejected'])->default('unverified');
            $table->text('rejection_reason')->nullable();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->uuid('verified_by')->nullable(); // Admin ID who approved KYC
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_kyc');
    }
};
