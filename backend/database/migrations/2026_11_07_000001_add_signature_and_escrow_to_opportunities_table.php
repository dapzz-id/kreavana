<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('opportunities', function (Blueprint $table) {
            $table->string('signature_type', 40)->default('dynamic_electronic')->after('escrow_status');
            $table->text('client_signature')->nullable()->after('signature_type');
            $table->timestamp('client_signed_at')->nullable()->after('client_signature');
            $table->string('wet_signature_document_url', 500)->nullable()->after('client_signed_at');
            $table->timestamp('wet_signature_verified_at')->nullable()->after('wet_signature_document_url');
            $table->decimal('escrow_amount', 15, 2)->default(0.00)->after('wet_signature_verified_at');
        });
    }

    public function down(): void
    {
        Schema::table('opportunities', function (Blueprint $table) {
            $table->dropColumn([
                'signature_type',
                'client_signature',
                'client_signed_at',
                'wet_signature_document_url',
                'wet_signature_verified_at',
                'escrow_amount',
            ]);
        });
    }
};

