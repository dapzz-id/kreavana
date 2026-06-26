<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('opportunities', function (Blueprint $table) {
            $table->enum('type', ['location', 'project'])->default('project')->after('pihak_slug');
            $table->decimal('latitude', 10, 7)->nullable()->after('location');
            $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            $table->string('location_category', 50)->nullable()->after('longitude');
            $table->string('address', 255)->nullable()->after('location_category');
        });

        Schema::table('creator_applications', function (Blueprint $table) {
            $table->string('ktp_photo_url', 500)->nullable()->after('experience');
            $table->string('nik', 16)->nullable()->after('ktp_photo_url');
            $table->string('full_name_ktp', 150)->nullable()->after('nik');
            $table->string('birth_place', 100)->nullable()->after('full_name_ktp');
            $table->date('birth_date')->nullable()->after('birth_place');
            $table->text('address_ktp')->nullable()->after('birth_date');
        });

        Schema::create('reports', function (Blueprint $table) {
            $table->integer('id')->autoIncrement();
            $table->integer('reporter_id');
            $table->enum('target_type', ['opportunity', 'user']);
            $table->integer('target_id');
            $table->string('reason', 100);
            $table->text('description')->nullable();
            $table->enum('status', ['pending', 'reviewed', 'resolved'])->default('pending');
            $table->timestamp('created_at')->useCurrent();

            $table->foreign('reporter_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reports');

        Schema::table('creator_applications', function (Blueprint $table) {
            $table->dropColumn([
                'ktp_photo_url', 'nik', 'full_name_ktp',
                'birth_place', 'birth_date', 'address_ktp',
            ]);
        });

        Schema::table('opportunities', function (Blueprint $table) {
            $table->dropColumn([
                'type', 'latitude', 'longitude',
                'location_category', 'address',
            ]);
        });
    }
};
