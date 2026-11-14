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
        if (Schema::hasTable('opportunities')) {
            Schema::table('opportunities', function (Blueprint $table) {
                if (!Schema::hasColumn('opportunities', 'meeting_counter_by')) {
                    $table->string('meeting_counter_by', 20)->nullable()->after('meeting_status');
                }
                if (!Schema::hasColumn('opportunities', 'meeting_counter_date')) {
                    $table->date('meeting_counter_date')->nullable()->after('meeting_counter_by');
                }
                if (!Schema::hasColumn('opportunities', 'meeting_counter_time')) {
                    $table->string('meeting_counter_time', 50)->nullable()->after('meeting_counter_date');
                }
                if (!Schema::hasColumn('opportunities', 'meeting_counter_location')) {
                    $table->text('meeting_counter_location')->nullable()->after('meeting_counter_time');
                }
                if (!Schema::hasColumn('opportunities', 'meeting_counter_lat')) {
                    $table->decimal('meeting_counter_lat', 10, 7)->nullable()->after('meeting_counter_location');
                }
                if (!Schema::hasColumn('opportunities', 'meeting_counter_lng')) {
                    $table->decimal('meeting_counter_lng', 10, 7)->nullable()->after('meeting_counter_lat');
                }
                if (!Schema::hasColumn('opportunities', 'meeting_counter_notes')) {
                    $table->text('meeting_counter_notes')->nullable()->after('meeting_counter_lng');
                }
                if (!Schema::hasColumn('opportunities', 'meeting_counter_status')) {
                    $table->string('meeting_counter_status', 30)->nullable()->after('meeting_counter_notes');
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
                $columns = [
                    'meeting_counter_by',
                    'meeting_counter_date',
                    'meeting_counter_time',
                    'meeting_counter_location',
                    'meeting_counter_lat',
                    'meeting_counter_lng',
                    'meeting_counter_notes',
                    'meeting_counter_status',
                ];
                foreach ($columns as $column) {
                    if (Schema::hasColumn('opportunities', $column)) {
                        $table->dropColumn($column);
                    }
                }
            });
        }
    }
};
