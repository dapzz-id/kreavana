<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('type', 50);              // topup, transfer_send, transfer_receive, withdrawal, etc.
            $table->decimal('amount', 15, 2);
            $table->decimal('fee', 15, 2)->default(0.00);
            $table->string('payment_method', 50);    // e-wallet, bank_transfer, qris, wallet
            $table->string('payment_provider', 100)->nullable();
            $table->enum('status', ['pending', 'completed', 'failed'])->default('pending');
            $table->string('reference_number', 100)->unique();
            $table->text('description')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallet_transactions');
    }
};
