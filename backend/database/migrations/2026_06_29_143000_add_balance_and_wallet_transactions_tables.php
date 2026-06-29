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
        // 1. Add balance column to users table
        if (Schema::hasTable('users') && !Schema::hasColumn('users', 'balance')) {
            Schema::table('users', function (Blueprint $table) {
                $table->decimal('balance', 15, 2)->default(0.00)->after('is_creator_approved');
            });
        }

        // 2. Create wallet_transactions table
        if (!Schema::hasTable('wallet_transactions')) {
            Schema::create('wallet_transactions', function (Blueprint $table) {
                $table->integer('id')->autoIncrement();
                $table->integer('user_id');
                $table->enum('type', ['topup', 'transfer_send', 'transfer_receive']);
                $table->decimal('amount', 15, 2);
                $table->decimal('fee', 15, 2)->default(0.00); // Admin fee / tax
                $table->string('payment_method', 50); // e-wallet, bank_transfer, qris, wallet
                $table->string('payment_provider', 100)->nullable(); // e.g. BCA, DANA, GoPay
                $table->enum('status', ['pending', 'completed', 'failed'])->default('pending');
                $table->string('reference_number', 100)->unique();
                $table->text('description')->nullable();
                $table->timestamps();

                $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('wallet_transactions');

        if (Schema::hasTable('users') && Schema::hasColumn('users', 'balance')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('balance');
            });
        }
    }
};
