<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('client_apps', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('client_id')->unique(); // e.g. kreavana_web, kreavana_mobile, app_b
            $table->string('client_name');
            $table->string('client_secret');
            $table->text('redirect_uris')->nullable();
            $table->json('allowed_scopes')->nullable(); // ['openid', 'profile', 'email', 'kyc']
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('client_apps');
    }
};
