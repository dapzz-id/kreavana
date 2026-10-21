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
        Schema::table('users', function (Blueprint $table) {
            // Drop password as authentication is fully delegated to users_api
            if (Schema::hasColumn('users', 'password')) {
                $table->dropColumn('password');
            }

            // Add local app suspension columns
            if (!Schema::hasColumn('users', 'is_suspended')) {
                $table->boolean('is_suspended')->default(false)->after('is_creator_approved');
            }
            if (!Schema::hasColumn('users', 'suspended_until')) {
                $table->timestamp('suspended_until')->nullable()->after('is_suspended');
            }
            if (!Schema::hasColumn('users', 'suspend_reason')) {
                $table->text('suspend_reason')->nullable()->after('suspended_until');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'password')) {
                $table->string('password')->nullable();
            }
            if (Schema::hasColumn('users', 'is_suspended')) {
                $table->dropColumn(['is_suspended', 'suspended_until', 'suspend_reason']);
            }
        });
    }
};
