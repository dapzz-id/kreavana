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
        Schema::table('messages', function (Blueprint $table) {
            $table->unsignedTinyInteger('encryption_version')->default(0)->after('message');
            $table->text('ciphertext')->nullable()->after('encryption_version');
            $table->string('iv', 255)->nullable()->after('ciphertext');
            
            // Note: message column remains TEXT, not nullable. For E2EE version 1, 
            // the backend might require it to be empty string or we can just make it nullable.
            // But to be safe and backward compatible, we keep it as is, we can just store empty string or "[E2EE]" if version 1.
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->dropColumn(['encryption_version', 'ciphertext', 'iv']);
        });
    }
};
