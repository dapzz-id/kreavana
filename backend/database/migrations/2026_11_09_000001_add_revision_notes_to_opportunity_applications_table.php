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
        if (Schema::hasTable('opportunity_applications')) {
            Schema::table('opportunity_applications', function (Blueprint $table) {
                if (!Schema::hasColumn('opportunity_applications', 'revision_notes')) {
                    $table->text('revision_notes')->nullable()->after('worker_status');
                }
            });
        }

        if (Schema::hasTable('job_contracts')) {
            Schema::table('job_contracts', function (Blueprint $table) {
                if (!Schema::hasColumn('job_contracts', 'revision_notes')) {
                    $table->text('revision_notes')->nullable()->after('cancel_reason');
                }
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('opportunity_applications')) {
            Schema::table('opportunity_applications', function (Blueprint $table) {
                if (Schema::hasColumn('opportunity_applications', 'revision_notes')) {
                    $table->dropColumn('revision_notes');
                }
            });
        }

        if (Schema::hasTable('job_contracts')) {
            Schema::table('job_contracts', function (Blueprint $table) {
                if (Schema::hasColumn('job_contracts', 'revision_notes')) {
                    $table->dropColumn('revision_notes');
                }
            });
        }
    }
};
