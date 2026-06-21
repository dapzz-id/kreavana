<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Tracks photo purchase transactions.
     * payment_status flows: pending → completed | failed.
     * midtrans_transaction_id links to payment gateway reference.
     */
    public function up(): void
    {
        Schema::create('purchases', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('photo_id')->constrained('photos')->cascadeOnDelete();
            $table->decimal('amount', 15, 2);
            $table->enum('payment_status', ['pending', 'completed', 'failed'])->default('pending');
            $table->string('midtrans_transaction_id')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('purchases');
    }
};
