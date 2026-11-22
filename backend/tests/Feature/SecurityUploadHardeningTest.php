<?php

namespace Tests\Feature;

use App\Enums\RoleType;
use App\Models\Opportunity;
use App\Models\StorageFile;
use App\Models\User;
use App\Services\ProfileService;
use App\Services\StorageService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;
use Tymon\JWTAuth\Facades\JWTAuth;

class SecurityUploadHardeningTest extends TestCase
{
    use RefreshDatabase;

    protected function authHeaders(User $user): array
    {
        return ['Authorization' => 'Bearer ' . JWTAuth::fromUser($user)];
    }

    private function sampleScriptTag(): string
    {
        return '<' . '?php echo "blocked"; ?' . '>';
    }

    public function test_storage_service_blocks_php_and_dangerous_extensions(): void
    {
        Storage::fake('public');
        $user = User::factory()->create(['role' => RoleType::Creator]);
        /** @var StorageService $storageService */
        $storageService = app(StorageService::class);

        foreach (['sample.php', 'sample.phtml', 'sample.phar', 'sample.sh', 'sample.svg', 'double.php.jpg'] as $badName) {
            $file = UploadedFile::fake()->createWithContent($badName, $this->sampleScriptTag());
            $rejected = false;
            try {
                $storageService->store($user, $file, 'avatar', 'public');
            } catch (\Exception $e) {
                $rejected = true;
            }
            $this->assertTrue($rejected, "Expected dangerous upload '{$badName}' to be rejected.");
        }
    }

    public function test_storage_service_blocks_polyglot_script_disguised_as_jpg(): void
    {
        Storage::fake('public');
        $user = User::factory()->create(['role' => RoleType::Creator]);
        /** @var StorageService $storageService */
        $storageService = app(StorageService::class);

        $polyglot = UploadedFile::fake()->createWithContent('avatar.jpg', "\xFF\xD8\xFF\xE0" . $this->sampleScriptTag());

        $this->expectException(\Exception::class);
        $storageService->store($user, $polyglot, 'avatar', 'public');
    }

    public function test_profile_service_rejects_base64_php_and_svg_avatars(): void
    {
        $user = User::factory()->create(['role' => RoleType::Creator]);
        /** @var ProfileService $profileService */
        $profileService = app(ProfileService::class);

        $phpPayload = 'data:image/php;base64,' . base64_encode($this->sampleScriptTag());
        $rejectedPhp = false;
        try {
            $profileService->updateProfile($user->id, ['avatar_url' => $phpPayload]);
        } catch (\Exception $e) {
            $rejectedPhp = true;
        }
        $this->assertTrue($rejectedPhp, 'Base64 data:image/php must be rejected.');

        $svgPayload = 'data:image/svg+xml;base64,' . base64_encode('<svg><title>blocked</title></svg>');
        $rejectedSvg = false;
        try {
            $profileService->updateProfile($user->id, ['avatar_url' => $svgPayload]);
        } catch (\Exception $e) {
            $rejectedSvg = true;
        }
        $this->assertTrue($rejectedSvg, 'Base64 data:image/svg+xml must be rejected.');
    }

    public function test_official_acceptance_letter_endpoint_rejects_php_upload(): void
    {
        Storage::fake('public');
        $owner = User::factory()->create(['role' => RoleType::User, 'sub_role' => 'corporate']);
        $opp = Opportunity::create([
            'posted_by' => $owner->id,
            'title' => 'Program Magang Security Test',
            'description' => 'Testing upload validation',
            'status' => 'open',
            'sub_role_slug' => 'magang',
        ]);

        $phpFile = UploadedFile::fake()->createWithContent('letter.php', $this->sampleScriptTag());

        $response = $this->withHeaders($this->authHeaders($owner))
            ->post('/api/opportunities/' . $opp->id . '/official-acceptance-letter', [
                'file' => $phpFile,
            ]);

        $this->assertContains($response->status(), [400, 422]);
    }

    public function test_private_chat_attachment_cannot_be_downloaded_without_authentication(): void
    {
        Storage::fake('private');
        $owner = User::factory()->create(['role' => RoleType::User]);

        Storage::disk('private')->put('chat_attachment/secret.txt', 'private content');
        $sf = StorageFile::create([
            'user_id' => $owner->id,
            'original_name' => 'secret.txt',
            'stored_name' => 'secret.txt',
            'disk' => 'private',
            'path' => 'chat_attachment/secret.txt',
            'category' => 'chat_attachment',
            'visibility' => 'private',
            'mime_type' => 'text/plain',
            'size' => 15,
            'checksum' => hash('sha256', 'private content'),
        ]);

        $response = $this->getJson('/api/storage/' . $sf->id . '/download');
        $this->assertContains($response->status(), [401, 403]);
    }

    public function test_api_responses_include_security_headers(): void
    {
        $response = $this->getJson('/api/system/module-statuses');
        $response->assertHeader('X-Content-Type-Options', 'nosniff');
        $response->assertHeader('X-Frame-Options', 'DENY');
        $response->assertHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    }
}
