<?php

use Illuminate\Support\Facades\Artisan;

Artisan::command('iam:purge-expired-sessions', function () {
    $count = \App\Models\UserSession::where('expires_at', '<', now())
        ->orWhere('is_revoked', true)
        ->delete();
    $this->info("Purged {$count} expired/revoked sessions.");
})->purpose('Purge expired and revoked sessions from the database');
