<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_addresses', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('label')->default('Home'); // Home, Office, Studio
            $table->string('recipient_name');
            $table->string('phone_number', 30);
            $table->text('street_address');
            $table->string('district')->nullable();
            $table->string('city');
            $table->string('state'); // Province
            $table->string('postal_code', 20);
            $table->string('country', 10)->default('ID');
            $table->decimal('latitude', 10, 8)->nullable();
            $table->decimal('longitude', 11, 8)->nullable();
            $table->boolean('is_default')->default(false);
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_addresses');
    }
};
