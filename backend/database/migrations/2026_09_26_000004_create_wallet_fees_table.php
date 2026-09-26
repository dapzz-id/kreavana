<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wallet_fees', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->enum('transaction_type', ['topup', 'withdraw', 'transfer', 'escrow', 'subscription'])->index();
            $table->string('payment_provider_code')->nullable()->index();
            $table->decimal('fee_percent', 5, 2)->default(0);
            $table->decimal('fee_flat_amount', 15, 2)->default(0);
            $table->decimal('min_fee', 15, 2)->default(0);
            $table->decimal('max_fee', 15, 2)->nullable();
            $table->decimal('min_transaction_amount', 15, 2)->default(10000);
            $table->decimal('max_transaction_amount', 15, 2)->default(500000000);
            $table->timestamp('effective_from')->nullable();
            $table->timestamp('effective_to')->nullable();
            $table->boolean('is_active')->default(true);
            $table->json('meta')->nullable();
            $table->timestamps();

            $table->unique(['transaction_type', 'payment_provider_code', 'effective_from'], 'wallet_fees_type_provider_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallet_fees');
    }
};
