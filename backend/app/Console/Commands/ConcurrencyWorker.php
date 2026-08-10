<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Http\Request;
use App\Http\Controllers\DisputeController;
use Illuminate\Support\Facades\Auth;
use App\Models\User;

class ConcurrencyWorker extends Command
{
    protected $signature = 'test:worker {action} {disputeId} {adminId}';
    protected $description = 'Worker for concurrency tests';

    public function handle()
    {
        $action = $this->argument('action');
        $disputeId = $this->argument('disputeId');
        $adminId = $this->argument('adminId');

        $admin = User::find($adminId);
        Auth::login($admin);

        $controller = app(DisputeController::class);
        $request = new Request([
            'decision' => 'approve',
            'resolution' => 'Concurrency test resolution'
        ]);

        try {
            if ($action === 'refund') {
                $response = $controller->adminDecideRefund($request, $disputeId);
                $this->info("Result: " . $response->status());
            } elseif ($action === 'settle') {
                $response = $controller->adminSettleRefund($request, $disputeId);
                $this->info("Result: " . $response->status());
            }
        } catch (\Exception $e) {
            $this->error("Error: " . $e->getMessage());
        }
    }
}
