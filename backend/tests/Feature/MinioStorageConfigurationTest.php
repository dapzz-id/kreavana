<?php

namespace Tests\Feature;

use App\Models\StorageFile;
use App\Models\User;
use App\Services\StorageService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class MinioStorageConfigurationTest extends TestCase
{
    use RefreshDatabase;

    public function test_minio_disk_configuration_is_registered_properly(): void
    {
        $minioConfig = config('filesystems.disks.minio');

        $this->assertIsArray($minioConfig);
        $this->assertEquals('s3', $minioConfig['driver']);
        $this->assertEquals('kreavana', $minioConfig['bucket']);
        $this->assertEquals('http://127.0.0.1:9000', $minioConfig['endpoint']);
        $this->assertTrue($minioConfig['use_path_style_endpoint']);
    }

    public function test_storage_file_url_accessor_generates_correct_minio_url(): void
    {
        $user = User::factory()->create();

        $storageFile = StorageFile::create([
            'user_id' => $user->id,
            'original_name' => 'poster.jpg',
            'stored_name' => 'sample-uuid.jpg',
            'disk' => 'minio',
            'path' => 'posters/sample-uuid.jpg',
            'category' => 'posters',
            'visibility' => 'public',
            'size' => 2048,
        ]);

        $this->assertEquals('http://127.0.0.1:9000/kreavana/posters/sample-uuid.jpg', $storageFile->url);
    }

    public function test_storage_file_private_url_routes_through_view_endpoint(): void
    {
        $user = User::factory()->create();

        $storageFile = StorageFile::create([
            'user_id' => $user->id,
            'original_name' => 'ktp.jpg',
            'stored_name' => 'ktp-uuid.jpg',
            'disk' => 'minio',
            'path' => 'kyc/ktp-uuid.jpg',
            'category' => 'kyc',
            'visibility' => 'private',
            'size' => 2048,
        ]);

        $this->assertStringContainsString('/api/storage/' . $storageFile->id . '/view', $storageFile->url);
    }

    public function test_storage_service_respects_minio_default_disk(): void
    {
        Storage::fake('minio');
        Config::set('filesystems.default', 'minio');

        $user = User::factory()->create();
        $file = UploadedFile::fake()->image('test-avatar.png');

        $service = app(StorageService::class);
        $storageFile = $service->store($user, $file, 'avatar', 'public');

        $this->assertEquals('minio', $storageFile->disk);
        $this->assertTrue(Storage::disk('minio')->exists($storageFile->path));
    }
}
