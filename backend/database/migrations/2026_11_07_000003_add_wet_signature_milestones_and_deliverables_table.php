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
        // 1. Kolom tambahan pada tabel opportunities
        if (Schema::hasTable('opportunities')) {
            Schema::table('opportunities', function (Blueprint $table) {
                if (!Schema::hasColumn('opportunities', 'admin_started_at')) {
                    $table->timestamp('admin_started_at')->nullable()->after('wet_signature_verified_at');
                }
                if (!Schema::hasColumn('opportunities', 'auto_release_triggered_at')) {
                    $table->timestamp('auto_release_triggered_at')->nullable()->after('admin_started_at');
                }
            });
        }

        // 2. Kolom tambahan pada tabel opportunity_requirements
        if (Schema::hasTable('opportunity_requirements')) {
            Schema::table('opportunity_requirements', function (Blueprint $table) {
                if (!Schema::hasColumn('opportunity_requirements', 'payment_scheme')) {
                    $table->string('payment_scheme', 40)->default('full_at_end')->after('notes');
                }
                if (!Schema::hasColumn('opportunity_requirements', 'payment_terms')) {
                    $table->json('payment_terms')->nullable()->after('payment_scheme');
                }
            });
        }

        // 3. Kolom tambahan pada tabel opportunity_applications
        if (Schema::hasTable('opportunity_applications')) {
            Schema::table('opportunity_applications', function (Blueprint $table) {
                if (!Schema::hasColumn('opportunity_applications', 'payment_scheme')) {
                    $table->string('payment_scheme', 40)->default('full_at_end')->after('dynamic_terms');
                }
                if (!Schema::hasColumn('opportunity_applications', 'payment_terms')) {
                    $table->json('payment_terms')->nullable()->after('payment_scheme');
                }
                if (!Schema::hasColumn('opportunity_applications', 'paid_amount')) {
                    $table->decimal('paid_amount', 15, 2)->default(0.00)->after('payment_terms');
                }
                if (!Schema::hasColumn('opportunity_applications', 'payment_status')) {
                    $table->string('payment_status', 40)->default('unpaid')->after('paid_amount');
                }
                if (!Schema::hasColumn('opportunity_applications', 'worker_progress')) {
                    $table->integer('worker_progress')->default(0)->after('payment_status');
                }
                if (!Schema::hasColumn('opportunity_applications', 'worker_status')) {
                    $table->string('worker_status', 40)->default('assigned')->after('worker_progress');
                }
                if (!Schema::hasColumn('opportunity_applications', 'submitted_deliverables')) {
                    $table->json('submitted_deliverables')->nullable()->after('submitted_documents');
                }
                if (!Schema::hasColumn('opportunity_applications', 'grace_period_deadline')) {
                    $table->timestamp('grace_period_deadline')->nullable()->after('worker_status');
                }
                if (!Schema::hasColumn('opportunity_applications', 'auto_released_at')) {
                    $table->timestamp('auto_released_at')->nullable()->after('grace_period_deadline');
                }
            });
        }

        // 4. Kolom tambahan pada tabel job_contracts
        if (Schema::hasTable('job_contracts')) {
            Schema::table('job_contracts', function (Blueprint $table) {
                if (!Schema::hasColumn('job_contracts', 'payment_scheme')) {
                    $table->string('payment_scheme', 40)->default('full_at_end')->after('dynamic_terms');
                }
                if (!Schema::hasColumn('job_contracts', 'payment_terms')) {
                    $table->json('payment_terms')->nullable()->after('payment_scheme');
                }
                if (!Schema::hasColumn('job_contracts', 'paid_amount')) {
                    $table->decimal('paid_amount', 15, 2)->default(0.00)->after('payment_terms');
                }
                if (!Schema::hasColumn('job_contracts', 'payment_status')) {
                    $table->string('payment_status', 40)->default('unpaid')->after('paid_amount');
                }
                if (!Schema::hasColumn('job_contracts', 'worker_progress')) {
                    $table->integer('worker_progress')->default(0)->after('payment_status');
                }
                if (!Schema::hasColumn('job_contracts', 'deliverables')) {
                    $table->json('deliverables')->nullable()->after('worker_progress');
                }
                if (!Schema::hasColumn('job_contracts', 'grace_period_deadline')) {
                    $table->timestamp('grace_period_deadline')->nullable()->after('deliverables');
                }
                if (!Schema::hasColumn('job_contracts', 'auto_released_at')) {
                    $table->timestamp('auto_released_at')->nullable()->after('grace_period_deadline');
                }
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('opportunities')) {
            Schema::table('opportunities', function (Blueprint $table) {
                $cols = ['admin_started_at', 'auto_release_triggered_at'];
                foreach ($cols as $c) {
                    if (Schema::hasColumn('opportunities', $c)) {
                        $table->dropColumn($c);
                    }
                }
            });
        }

        if (Schema::hasTable('opportunity_requirements')) {
            Schema::table('opportunity_requirements', function (Blueprint $table) {
                $cols = ['payment_scheme', 'payment_terms'];
                foreach ($cols as $c) {
                    if (Schema::hasColumn('opportunity_requirements', $c)) {
                        $table->dropColumn($c);
                    }
                }
            });
        }

        if (Schema::hasTable('opportunity_applications')) {
            Schema::table('opportunity_applications', function (Blueprint $table) {
                $cols = [
                    'payment_scheme',
                    'payment_terms',
                    'paid_amount',
                    'payment_status',
                    'worker_progress',
                    'worker_status',
                    'submitted_deliverables',
                    'grace_period_deadline',
                    'auto_released_at',
                ];
                foreach ($cols as $c) {
                    if (Schema::hasColumn('opportunity_applications', $c)) {
                        $table->dropColumn($c);
                    }
                }
            });
        }

        if (Schema::hasTable('job_contracts')) {
            Schema::table('job_contracts', function (Blueprint $table) {
                $cols = [
                    'payment_scheme',
                    'payment_terms',
                    'paid_amount',
                    'payment_status',
                    'worker_progress',
                    'deliverables',
                    'grace_period_deadline',
                    'auto_released_at',
                ];
                foreach ($cols as $c) {
                    if (Schema::hasColumn('job_contracts', $c)) {
                        $table->dropColumn($c);
                    }
                }
            });
        }
    }
};
