<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('opportunity_applications', function (Blueprint $table) {
            if (!Schema::hasColumn('opportunity_applications', 'contract_number')) {
                $table->string('contract_number')->nullable()->after('dynamic_terms');
            }
            if (!Schema::hasColumn('opportunity_applications', 'client_signature')) {
                $table->text('client_signature')->nullable()->after('contract_number');
            }
            if (!Schema::hasColumn('opportunity_applications', 'client_signed_at')) {
                $table->timestamp('client_signed_at')->nullable()->after('client_signature');
            }
        });
    }

    public function down(): void
    {
        Schema::table('opportunity_applications', function (Blueprint $table) {
            $dropCols = [];
            foreach (['contract_number', 'client_signature', 'client_signed_at'] as $col) {
                if (Schema::hasColumn('opportunity_applications', $col)) {
                    $dropCols[] = $col;
                }
            }
            if (!empty($dropCols)) {
                $table->dropColumn($dropCols);
            }
        });
    }
};
