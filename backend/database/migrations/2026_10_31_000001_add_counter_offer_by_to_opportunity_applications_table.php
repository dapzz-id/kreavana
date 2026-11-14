<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('opportunity_applications', function (Blueprint $table) {
            if (!Schema::hasColumn('opportunity_applications', 'counter_offer_by')) {
                $table->string('counter_offer_by', 20)->default('client')->nullable()->after('counter_offer_status');
            }
        });
    }

    public function down(): void
    {
        Schema::table('opportunity_applications', function (Blueprint $table) {
            if (Schema::hasColumn('opportunity_applications', 'counter_offer_by')) {
                $table->dropColumn('counter_offer_by');
            }
        });
    }
};
