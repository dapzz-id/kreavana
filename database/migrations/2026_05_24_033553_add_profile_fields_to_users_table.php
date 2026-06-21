<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('username')->nullable()->unique()->after('name');
            $table->string('bio', 500)->nullable()->after('email');
            $table->string('profile_photo_path')->nullable()->after('bio');
            $table->string('website')->nullable()->after('profile_photo_path');
            $table->json('face_embeddings')->nullable()->after('website'); // RoboYu AI face data
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['username', 'bio', 'profile_photo_path', 'website', 'face_embeddings']);
        });
    }
};
