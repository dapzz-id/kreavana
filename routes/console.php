<?php

use App\Http\Controllers\StoryController;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

// ── Built-in commands ────────────────────────────────────────────────────────
Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// ── Custom: Prune expired stories (runs every hour via scheduler) ─────────────
Artisan::command('stories:prune', function () {
    $count = StoryController::pruneExpired();
    $this->info("Pruned {$count} expired stories.");
})->purpose('Delete expired stories and their files from storage');

// ── Schedule hourly pruning ───────────────────────────────────────────────────
Schedule::command('stories:prune')->hourly();
