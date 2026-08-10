<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\UserSession;
use Illuminate\Support\Carbon;

class CleanupAuthSessions extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'auth:cleanup-sessions {--days=30 : The number of days to retain revoked/expired sessions}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Clean up expired or revoked authentication sessions and their associated refresh tokens in chunks.';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $days = (int) $this->option('days');
        $retentionDate = Carbon::now()->subDays($days);

        $this->info("Starting auth session cleanup. Deleting sessions expired or revoked before {$retentionDate->toDateTimeString()}...");

        $deletedCount = 0;
        $chunkSize = 500;

        while (true) {
            // Using a limit approach for UUIDs is safer than chunkById and avoids massive lock issues.
            $ids = UserSession::where(function ($query) use ($retentionDate) {
                    $query->where('expires_at', '<', $retentionDate)
                          ->orWhere('revoked_at', '<', $retentionDate);
                })
                ->limit($chunkSize)
                ->pluck('id');

            if ($ids->isEmpty()) {
                break;
            }

            // Since user_sessions has an onDelete('cascade') for refresh_tokens,
            // deleting the user_sessions will automatically delete the related refresh tokens.
            $count = UserSession::whereIn('id', $ids)->delete();
            $deletedCount += $count;
            
            $this->info("Deleted chunk of {$count} sessions...");
        }

        $this->info("Cleanup completed. Total sessions deleted: {$deletedCount}");
    }
}
