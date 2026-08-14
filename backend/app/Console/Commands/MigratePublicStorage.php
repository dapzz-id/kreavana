<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Models\StorageFile;
use App\Services\StorageService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\UploadedFile;

class MigratePublicStorage extends Command
{
    protected $signature = 'storage:migrate-public';
    protected $description = 'Migrate legacy public uploads to Centralized Storage';

    protected StorageService $storageService;

    public function __construct(StorageService $storageService)
    {
        parent::__construct();
        $this->storageService = $storageService;
    }

    public function handle()
    {
        $this->info('Starting legacy storage migration...');
        
        $this->migrateAvatars();
        $this->migrateChatAudio();
        
        $this->info('Migration completed.');
    }

    private function migrateAvatars()
    {
        $this->info('Migrating avatars...');
        $avatarPath = public_path('avatars');
        if (!is_dir($avatarPath)) return;

        $files = scandir($avatarPath);
        foreach ($files as $file) {
            if ($file === '.' || $file === '..') continue;
            
            $path = $avatarPath . '/' . $file;
            if (!is_file($path)) continue;

            $this->info("Processing avatar: $file");

            // Extract user ID from avatar format: avatar_{uuid}_{time}.ext
            preg_match('/^avatar_([a-f0-9\-]+)_/i', $file, $matches);
            if (empty($matches[1])) {
                $this->warn("Could not determine owner for: $file [UNRESOLVED MIGRATION ITEM]");
                continue;
            }

            $userId = $matches[1];
            $user = User::find($userId);

            if (!$user) {
                $this->warn("User $userId not found for file: $file [UNRESOLVED MIGRATION ITEM]");
                continue;
            }

            // Check if already migrated (assuming avatar url was updated to storage/...)
            if (str_contains($user->avatar_url, 'storage/avatar/')) {
                $this->info("Already migrated: $file");
                continue;
            }

            try {
                $uploadedFile = new UploadedFile($path, $file, mime_content_type($path), null, true);
                
                DB::beginTransaction();
                $storageFile = $this->storageService->store($user, $uploadedFile, 'avatar', 'public');
                
                $user->avatar_url = url('storage/' . $storageFile->path);
                $user->save();
                DB::commit();

                // Only delete old file if successful
                @unlink($path);
                $this->info("Successfully migrated: $file");
            } catch (\Exception $e) {
                DB::rollBack();
                $this->error("Failed to migrate $file: " . $e->getMessage());
            }
        }
    }

    private function migrateChatAudio()
    {
        $this->info('Migrating chat audio...');
        // Implement chat audio mapping to chat messages based on database references
    }
}
