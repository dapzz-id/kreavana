<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_verified')->default(false)->after('is_creator_approved');
            $table->string('verification_type', 30)->nullable()->after('is_verified'); // 'client' or 'creator'
            $table->timestamp('verified_at')->nullable()->after('verification_type');
            $table->string('nik', 16)->nullable()->after('verified_at');
            $table->string('full_name_ktp', 150)->nullable()->after('nik');
            $table->string('ktp_photo_url', 500)->nullable()->after('full_name_ktp');
            $table->string('selfie_photo_url', 500)->nullable()->after('ktp_photo_url');
            $table->string('nib_number', 50)->nullable()->after('selfie_photo_url');
            $table->string('nib_file_url', 500)->nullable()->after('nib_number');
        });

        Schema::table('creator_applications', function (Blueprint $table) {
            $table->string('type', 30)->default('creator_upgrade')->after('user_id'); // 'client_verification' or 'creator_upgrade'
            $table->string('nib_number', 50)->nullable()->after('address_ktp');
            $table->string('nib_file_url', 500)->nullable()->after('nib_number');
            $table->boolean('reused_ktp')->default(false)->after('nib_file_url');
        });

        // Set existing approved creators as verified creators (Centang Hijau)
        DB::table('users')
            ->where('is_creator_approved', 1)
            ->orWhere('role', 'creator')
            ->update([
                'is_verified' => 1,
                'verification_type' => 'creator',
                'verified_at' => now(),
            ]);
    }

    public function down(): void
    {
        Schema::table('creator_applications', function (Blueprint $table) {
            $table->dropColumn(['type', 'nib_number', 'nib_file_url', 'reused_ktp']);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'is_verified',
                'verification_type',
                'verified_at',
                'nik',
                'full_name_ktp',
                'ktp_photo_url',
                'selfie_photo_url',
                'nib_number',
                'nib_file_url',
            ]);
        });
    }
};
