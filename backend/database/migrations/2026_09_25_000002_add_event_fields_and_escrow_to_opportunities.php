<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('opportunities', function (Blueprint $table) {
            $table->date('event_start_date')->nullable()->after('event_date');
            $table->date('event_end_date')->nullable()->after('event_start_date');
            $table->string('banner_url', 500)->nullable()->after('poster_url');
            $table->date('meeting_date')->nullable()->after('event_end_time');
            $table->string('meeting_time', 30)->nullable()->after('meeting_date');
            $table->string('meeting_location', 255)->nullable()->after('meeting_time');
            $table->decimal('meeting_lat', 10, 7)->nullable()->after('meeting_location');
            $table->decimal('meeting_lng', 10, 7)->nullable()->after('meeting_lat');
            $table->text('meeting_notes')->nullable()->after('meeting_lng');
            $table->string('meeting_status', 40)->default('not_required')->after('meeting_notes');
            $table->string('escrow_status', 40)->default('none')->after('meeting_status');
            $table->integer('event_progress')->default(0)->after('escrow_status');
        });

        Schema::table('opportunity_applications', function (Blueprint $table) {
            $table->json('submitted_documents')->nullable()->after('questions_notes');
        });
    }

    public function down(): void
    {
        Schema::table('opportunities', function (Blueprint $table) {
            $table->dropColumn([
                'event_start_date',
                'event_end_date',
                'banner_url',
                'meeting_date',
                'meeting_time',
                'meeting_location',
                'meeting_lat',
                'meeting_lng',
                'meeting_notes',
                'meeting_status',
                'escrow_status',
                'event_progress',
            ]);
        });

        Schema::table('opportunity_applications', function (Blueprint $table) {
            $table->dropColumn(['submitted_documents']);
        });
    }
};
