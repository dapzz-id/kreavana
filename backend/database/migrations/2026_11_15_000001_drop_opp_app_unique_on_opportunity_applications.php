<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('opportunity_applications')) {
            return;
        }

        Schema::table('opportunity_applications', function (Blueprint $table) {
            if (!Schema::hasIndex('opportunity_applications', 'opp_app_lookup_idx')) {
                $table->index(['opportunity_id', 'creator_id', 'sub_role_slug'], 'opp_app_lookup_idx');
            }
            if (Schema::hasIndex('opportunity_applications', 'opp_app_unique')) {
                $table->dropUnique('opp_app_unique');
            }
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('opportunity_applications')) {
            return;
        }

        Schema::table('opportunity_applications', function (Blueprint $table) {
            if (!Schema::hasIndex('opportunity_applications', 'opp_app_unique')) {
                $table->unique(['opportunity_id', 'creator_id', 'sub_role_slug'], 'opp_app_unique');
            }
            if (Schema::hasIndex('opportunity_applications', 'opp_app_lookup_idx')) {
                $table->dropIndex('opp_app_lookup_idx');
            }
        });
    }
};
