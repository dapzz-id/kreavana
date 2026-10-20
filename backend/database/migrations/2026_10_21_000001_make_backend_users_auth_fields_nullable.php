<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * Makes auth-related fields nullable in backend users table
     * since authentication and credentials are now handled by users_api.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Password is now managed by users_api, making it nullable in backend
            $table->string('password')->nullable()->change();

            // Remember token is obsolete for microservice JWT auth
            if (Schema::hasColumn('users', 'remember_token')) {
                $table->string('remember_token', 100)->nullable()->change();
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('password')->nullable(false)->change();
        });
    }
};
