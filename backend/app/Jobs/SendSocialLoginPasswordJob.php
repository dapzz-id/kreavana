<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use App\Mail\SocialLoginPasswordMail;

class SendSocialLoginPasswordJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public array $backoff = [10, 60];
    public int $timeout = 30;

    protected $email;
    protected $password;

    /**
     * Create a new job instance.
     */
    public function __construct(string $email, string $password)
    {
        $this->email = $email;
        $this->password = $password;
    }

    /**
     * Execute the job.
     */
    public function handle(): void
    {
        Mail::to($this->email)->send(new SocialLoginPasswordMail($this->email, $this->password));
    }

    /**
     * Record permanent mail failure in logs.
     */
    public function failed(\Throwable $e): void
    {
        Log::error('SendSocialLoginPasswordJob permanently failed', [
            'email' => $this->email,
            'error' => $e->getMessage(),
        ]);
    }
}
