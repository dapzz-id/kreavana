<?php

namespace App\Console\Commands;

use App\Models\StorageFile;
use Carbon\Carbon;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

#[Signature('storage:cleanup')]
#[Description('Permanently delete storage files metadata that have been soft deleted for more than 30 days.')]
class CleanupStorageFiles extends Command
{
    /**
     * Execute the console command.
     */
    public function handle()
    {
        $cutoffDate = Carbon::now()->subDays(30);

        // Find files that are soft-deleted and were deleted before the cutoff date
        $filesToCleanup = StorageFile::onlyTrashed()
            ->where('deleted_at', '<', $cutoffDate)
            ->get();

        $count = $filesToCleanup->count();
        if ($count === 0) {
            $this->info("No soft-deleted storage files older than 30 days found.");
            return;
        }

        foreach ($filesToCleanup as $file) {
            // Note: Physical file should have been deleted at the time of soft deletion in StorageService.
            // This command just cleans up the metadata from the database permanently.
            $file->forceDelete();
        }

        $this->info("Successfully cleaned up {$count} soft-deleted storage files.");
    }
}
