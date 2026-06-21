<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Tamper-evident financial ledger.
     * amount_encrypted → AES-256 encrypted transaction value.
     * hash_signature   → HMAC-SHA256 of this entry's data.
     * previous_hash    → previous entry's hash_signature (blockchain-style chain).
     * transaction_type → deposit (top-up), purchase (buy photo), earning (photographer payout), withdrawal.
     * reference_id     → optional payment gateway or order reference.
     */
    public function up(): void
    {
        Schema::create('ledgers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->text('amount_encrypted');
            $table->string('hash_signature');
            $table->string('previous_hash')->nullable();
            $table->enum('transaction_type', ['deposit', 'purchase', 'earning', 'withdrawal']);
            $table->string('reference_id')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ledgers');
    }
};
