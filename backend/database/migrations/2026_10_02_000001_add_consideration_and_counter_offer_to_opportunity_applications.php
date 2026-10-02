<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('opportunity_applications', function (Blueprint $table) {
            $table->decimal('counter_offer_price', 15, 2)->nullable()->after('bid_price');
            $table->text('counter_offer_notes')->nullable()->after('counter_offer_price');
            $table->string('counter_offer_status', 30)->nullable()->after('counter_offer_notes'); // 'pending', 'accepted', 'declined'
        });

        // Drop the old PostgreSQL check constraint if exists, and recreate with 'under_consideration'
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE opportunity_applications DROP CONSTRAINT IF EXISTS opportunity_applications_status_check;");
            DB::statement("ALTER TABLE opportunity_applications ADD CONSTRAINT opportunity_applications_status_check CHECK (status IN ('pending', 'approved', 'rejected', 'withdrawn', 'cancelled', 'under_consideration'));");
        }
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE opportunity_applications DROP CONSTRAINT IF EXISTS opportunity_applications_status_check;");
            DB::statement("ALTER TABLE opportunity_applications ADD CONSTRAINT opportunity_applications_status_check CHECK (status IN ('pending', 'approved', 'rejected', 'withdrawn', 'cancelled'));");
        }

        Schema::table('opportunity_applications', function (Blueprint $table) {
            $table->dropColumn(['counter_offer_price', 'counter_offer_notes', 'counter_offer_status']);
        });
    }
};
