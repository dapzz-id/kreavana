<?php

namespace App\Jobs;

use App\Mail\PasswordResetMail;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class SendPasswordResetJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public array $backoff = [10, 60];
    public int $timeout = 30;

    protected string $email;
    protected string $otp;
    protected ?string $name;

    /**
     * Create a new job instance.
     */
    public function __construct(string $email, string $otp, ?string $name = null)
    {
        $this->email = $email;
        $this->otp = $otp;
        $this->name = $name;
    }

    /**
     * Execute the job.
     */
    public function handle(): void
    {
        Mail::to($this->email)->send(new PasswordResetMail($this->otp, $this->name));
    }

    /**
     * Record permanent mail failure in logs.
     */
    public function failed(\Throwable $e): void
    {
        Log::error('SendPasswordResetJob permanently failed', [
            'email' => $this->email,
            'error' => $e->getMessage(),
        ]);
    }
}
