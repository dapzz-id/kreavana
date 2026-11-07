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
        // 1. Kolom tambahan pada tabel job_contracts untuk Tanda Tangan Digital Dynamic 3 Pihak
        if (Schema::hasTable('job_contracts')) {
            Schema::table('job_contracts', function (Blueprint $table) {
                if (!Schema::hasColumn('job_contracts', 'contract_number')) {
                    $table->string('contract_number', 80)->nullable()->unique()->after('id');
                }
                if (!Schema::hasColumn('job_contracts', 'dynamic_terms')) {
                    $table->json('dynamic_terms')->nullable()->after('terms');
                }
                if (!Schema::hasColumn('job_contracts', 'creator_signature')) {
                    $table->text('creator_signature')->nullable()->after('creator_approved_at');
                }
                if (!Schema::hasColumn('job_contracts', 'creator_signed_at')) {
                    $table->timestamp('creator_signed_at')->nullable()->after('creator_signature');
                }
                if (!Schema::hasColumn('job_contracts', 'client_signature')) {
                    $table->text('client_signature')->nullable()->after('client_approved_at');
                }
                if (!Schema::hasColumn('job_contracts', 'client_signed_at')) {
                    $table->timestamp('client_signed_at')->nullable()->after('client_signature');
                }
                if (!Schema::hasColumn('job_contracts', 'admin_name')) {
                    $table->string('admin_name', 150)->nullable()->after('client_signed_at');
                }
                if (!Schema::hasColumn('job_contracts', 'admin_signature_url')) {
                    $table->text('admin_signature_url')->nullable()->after('admin_name');
                }
                if (!Schema::hasColumn('job_contracts', 'admin_signed_at')) {
                    $table->timestamp('admin_signed_at')->nullable()->after('admin_signature_url');
                }
            });
        }

        // 2. Kolom tambahan pada tabel opportunities untuk ketentuan dinamis & pengesahan sistem
        if (Schema::hasTable('opportunities')) {
            Schema::table('opportunities', function (Blueprint $table) {
                if (!Schema::hasColumn('opportunities', 'dynamic_terms')) {
                    $table->json('dynamic_terms')->nullable()->after('client_signed_at');
                }
                if (!Schema::hasColumn('opportunities', 'admin_name')) {
                    $table->string('admin_name', 150)->nullable()->after('dynamic_terms');
                }
                if (!Schema::hasColumn('opportunities', 'admin_signature_url')) {
                    $table->text('admin_signature_url')->nullable()->after('admin_name');
                }
                if (!Schema::hasColumn('opportunities', 'admin_signed_at')) {
                    $table->timestamp('admin_signed_at')->nullable()->after('admin_signature_url');
                }
            });
        }

        // 3. Kolom tambahan pada opportunity_applications untuk usulan ketentuan dinamis pelamar
        if (Schema::hasTable('opportunity_applications')) {
            Schema::table('opportunity_applications', function (Blueprint $table) {
                if (!Schema::hasColumn('opportunity_applications', 'dynamic_terms')) {
                    $table->json('dynamic_terms')->nullable()->after('counter_offer_notes');
                }
                if (!Schema::hasColumn('opportunity_applications', 'creator_signature')) {
                    $table->text('creator_signature')->nullable()->after('dynamic_terms');
                }
                if (!Schema::hasColumn('opportunity_applications', 'creator_signed_at')) {
                    $table->timestamp('creator_signed_at')->nullable()->after('creator_signature');
                }
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('job_contracts')) {
            Schema::table('job_contracts', function (Blueprint $table) {
                $columns = [
                    'contract_number',
                    'dynamic_terms',
                    'creator_signature',
                    'creator_signed_at',
                    'client_signature',
                    'client_signed_at',
                    'admin_name',
                    'admin_signature_url',
                    'admin_signed_at',
                ];
                foreach ($columns as $column) {
                    if (Schema::hasColumn('job_contracts', $column)) {
                        $table->dropColumn($column);
                    }
                }
            });
        }

        if (Schema::hasTable('opportunities')) {
            Schema::table('opportunities', function (Blueprint $table) {
                $columns = ['dynamic_terms', 'admin_name', 'admin_signature_url', 'admin_signed_at'];
                foreach ($columns as $column) {
                    if (Schema::hasColumn('opportunities', $column)) {
                        $table->dropColumn($column);
                    }
                }
            });
        }

        if (Schema::hasTable('opportunity_applications')) {
            Schema::table('opportunity_applications', function (Blueprint $table) {
                $columns = ['dynamic_terms', 'creator_signature', 'creator_signed_at'];
                foreach ($columns as $column) {
                    if (Schema::hasColumn('opportunity_applications', $column)) {
                        $table->dropColumn($column);
                    }
                }
            });
        }
    }
};

