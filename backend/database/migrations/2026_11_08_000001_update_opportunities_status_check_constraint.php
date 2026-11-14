<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE opportunities DROP CONSTRAINT IF EXISTS opportunities_status_check;");
            DB::statement("ALTER TABLE opportunities ADD CONSTRAINT opportunities_status_check CHECK (status IN ('open', 'in_progress', 'ongoing', 'completed', 'closed', 'cancelled', 'under_dispute'));");
        } elseif (DB::getDriverName() === 'mysql') {
            DB::statement("ALTER TABLE opportunities MODIFY COLUMN status ENUM('open', 'in_progress', 'ongoing', 'completed', 'closed', 'cancelled', 'under_dispute') DEFAULT 'open';");
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (DB::getDriverName() === 'pgsql') {
            DB::statement("ALTER TABLE opportunities DROP CONSTRAINT IF EXISTS opportunities_status_check;");
            DB::statement("ALTER TABLE opportunities ADD CONSTRAINT opportunities_status_check CHECK (status IN ('open', 'closed', 'cancelled', 'under_dispute'));");
        } elseif (DB::getDriverName() === 'mysql') {
            DB::statement("ALTER TABLE opportunities MODIFY COLUMN status ENUM('open', 'closed', 'cancelled', 'under_dispute') DEFAULT 'open';");
        }
    }
};
