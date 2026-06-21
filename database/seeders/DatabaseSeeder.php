<?php

namespace Database\Seeders;

use App\Models\Role;
use App\Models\User;
use App\Models\Photo;
use App\Services\LedgerService;
use App\Services\WatermarkService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\File;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // 1. Create Roles
        $userRole = Role::updateOrCreate(['slug' => 'user'], ['name' => 'Regular User']);
        $photoRole = Role::updateOrCreate(['slug' => 'photographer'], ['name' => 'Photographer']);
        $adminRole = Role::updateOrCreate(['slug' => 'superadmin'], ['name' => 'Superadmin']);

        // 2. Create Users
        $adminUser = User::updateOrCreate([
            'email' => 'admin@kreavana.com'
        ], [
            'name' => 'Super Admin',
            'password' => Hash::make('password'),
            'role_id' => $adminRole->id,
        ]);

        $photographerUser = User::updateOrCreate([
            'email' => 'photo@kreavana.com'
        ], [
            'name' => 'Jane the Photographer',
            'password' => Hash::make('password'),
            'role_id' => $photoRole->id,
        ]);

        $regularUser = User::updateOrCreate([
            'email' => 'user@kreavana.com'
        ], [
            'name' => 'John Doe',
            'password' => Hash::make('password'),
            'role_id' => $userRole->id,
        ]);

        // 3. Seed User Ledger Balances
        $ledgerService = app(LedgerService::class);
        
        // Seed John Doe with Rp 1,500,000 to test buying photos
        // Check if user already has ledger entries to avoid double seeding
        if ($regularUser->ledgerEntries()->count() === 0) {
            $ledgerService->addTransaction($regularUser, 1500000.00, 'deposit', 'seeder_init');
        }

        // Seed Photographer with Rp 0 if they have no entries
        if ($photographerUser->ledgerEntries()->count() === 0) {
            $ledgerService->addTransaction($photographerUser, 0.00, 'deposit', 'seeder_init');
        }

        // 4. Seed Photos
        $watermarkService = app(WatermarkService::class);

        // Path settings
        $privatePath = storage_path('app/private/originals');
        $publicPath = storage_path('app/public/watermarked');

        if (!File::isDirectory($privatePath)) {
            File::makeDirectory($privatePath, 0755, true);
        }
        if (!File::isDirectory($publicPath)) {
            File::makeDirectory($publicPath, 0755, true);
        }

        // Source generated files (from artifact directory)
        $samplePhotos = [
            [
                'title' => 'Sunset Mountain Peak',
                'description' => 'A breathtaking view of the golden hour sun setting behind snow-capped mountain peaks.',
                'price' => 50000.00,
                'is_for_sale' => true,
                'tags' => 'sunset, mountain, nature, landscape, golden hour, peak',
                'artifact_file' => 'sunset_mountain_1779543428671.png',
                'local_filename' => 'sunset_mountain.png',
                'color' => [235, 120, 40] // GD fallback color (orange)
            ],
            [
                'title' => 'Cyberpunk Neon Street',
                'description' => 'Neon-lit street in a futuristic city reflecting off wet pavement during a rainy night.',
                'price' => 150000.00,
                'is_for_sale' => true,
                'tags' => 'city, street, neon, cyberpunk, night, rainy, reflections, purple',
                'artifact_file' => 'neon_city_1779543683600.png',
                'local_filename' => 'neon_city.png',
                'color' => [40, 180, 235] // GD fallback color (cyan)
            ],
            [
                'title' => 'Cute Garden Cat',
                'description' => 'A playful cute fluffy cat enjoying the morning sun in a lush green backyard.',
                'price' => 0.00,
                'is_for_sale' => false,
                'tags' => 'cat, animal, pet, cute, garden, green, grass, summer',
                'artifact_file' => 'cute_cat_1779543722619.png',
                'local_filename' => 'cute_cat.png',
                'color' => [120, 220, 100] // GD fallback color (green)
            ],
        ];

        $artifactDir = 'C:\Users\Dapzz\.gemini\antigravity-ide\brain\da58142c-196f-4707-bb28-66953ecdba95';

        foreach ($samplePhotos as $photoData) {
            $destOriginal = $privatePath . '/' . $photoData['local_filename'];
            $destWatermarked = $publicPath . '/' . $photoData['local_filename'];

            $sourceArtifact = $artifactDir . '/' . $photoData['artifact_file'];

            if (File::exists($sourceArtifact)) {
                // Copy from generated artifact
                File::copy($sourceArtifact, $destOriginal);
            } else {
                // GD fallback if artifact doesn't exist
                $this->createFallbackImage($destOriginal, $photoData['title'], $photoData['color']);
            }

            // Create watermarked version
            if ($photoData['is_for_sale']) {
                $watermarkService->applyWatermark($destOriginal, $destWatermarked);
            } else {
                // Free photos: Copy directly to watermarked folder or store without watermark
                File::copy($destOriginal, $destWatermarked);
            }

            // Save in database
            Photo::updateOrCreate([
                'title' => $photoData['title'],
                'user_id' => $photographerUser->id
            ], [
                'description' => $photoData['description'],
                'original_path' => 'originals/' . $photoData['local_filename'],
                'watermarked_path' => 'watermarked/' . $photoData['local_filename'],
                'price' => $photoData['price'],
                'is_for_sale' => $photoData['is_for_sale'],
                'tags' => $photoData['tags'],
            ]);
        }
    }

    /**
     * Create a fallback color canvas image with GD if the AI generated images are not found.
     */
    private function createFallbackImage(string $path, string $text, array $rgb): void
    {
        if (!extension_loaded('gd')) {
            // Write basic text file if GD not loaded
            File::put($path, "Fallback image content for: " . $text);
            return;
        }

        $width = 800;
        $height = 600;
        $im = @imagecreatetruecolor($width, $height);
        
        $background = imagecolorallocate($im, $rgb[0], $rgb[1], $rgb[2]);
        imagefill($im, 0, 0, $background);
        
        $textColor = imagecolorallocate($im, 255, 255, 255);
        $font = 5;
        
        $textWidth = imagefontwidth($font) * strlen($text);
        $textHeight = imagefontheight($font);
        
        $x = ($width - $textWidth) / 2;
        $y = ($height - $textHeight) / 2;
        
        imagestring($im, $font, $x, $y, $text, $textColor);
        imagestring($im, 3, $x, $y + 30, "[KREAVANA SAMPLE PHOTO]", $textColor);
        
        imagepng($im, $path);
        imagedestroy($im);
    }
}
