<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('job_contracts', function (Blueprint $table) {
            $table->date('scheduled_start_date')->nullable()->after('work_status');
            $table->date('scheduled_end_date')->nullable()->after('scheduled_start_date');
        });
    }

    public function down(): void
    {
        Schema::table('job_contracts', function (Blueprint $table) {
            $table->dropColumn(['scheduled_start_date', 'scheduled_end_date']);
        });
    }
};
