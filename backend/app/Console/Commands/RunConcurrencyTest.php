<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\User;
use App\Models\MarketplacePurchase;
use App\Models\MarketplaceItem;
use App\Models\DisputeCase;

class RunConcurrencyTest extends Command
{
    protected $signature = 'test:concurrency {db}';
    protected $description = 'Run a true parallel concurrency test directly against the DB';

    public function handle()
    {
        $db = $this->argument('db');
        $this->info("Running Concurrency Test against: " . $db);

        // We simulate concurrency using PHP processes or we can just rely on 
        // the fact that we can fork using popen.
        
        $admin = User::where('role', \App\Enums\RoleType::Admin)->first();
        if (!$admin) {
            $admin = User::factory()->create(['role' => 'admin', 'balance' => 0]);
        }

        $seller = User::factory()->create(['balance' => 100000]);
        $buyer = User::factory()->create(['balance' => 0]);
        
        $item = MarketplaceItem::create([
            'id' => \Illuminate\Support\Str::uuid(),
            'user_id' => $seller->id,
            'title' => 'Test Item',
            'category' => 'Test',
            'description' => 'Desc',
            'price' => 100000,
            'file_url' => 'test.zip'
        ]);
        
        $purchase = MarketplacePurchase::create([
            'id' => \Illuminate\Support\Str::uuid(),
            'user_id' => $buyer->id,
            'marketplace_item_id' => $item->id,
            'amount' => 100000,
            'status' => 'completed'
        ]);

        $dispute = DisputeCase::create([
            'case_type' => 'marketplace_refund',
            'requester_id' => $buyer->id,
            'other_party_id' => $seller->id,
            'assigned_admin_id' => $admin->id,
            'marketplace_purchase_id' => $purchase->id,
            'reason' => 'Defective',
            'status' => 'under_review'
        ]);

        // Launch 10 simultaneous workers
        $this->info("Spawning 10 concurrent requests...");
        $processes = [];
        for ($i = 0; $i < 10; $i++) {
            $process = new \Symfony\Component\Process\Process(['php', 'artisan', 'test:worker', 'refund', $dispute->id, $admin->id, '--env='.$db]);
            $process->start();
            $processes[] = $process;
        }

        $successCount = 0;
        $failCount = 0;
        
        while (count($processes) > 0) {
            foreach ($processes as $key => $process) {
                if (!$process->isRunning()) {
                    $output = $process->getOutput();
                    if (str_contains($output, 'Result: 200')) {
                        $successCount++;
                    } else {
                        $failCount++;
                    }
                    unset($processes[$key]);
                }
            }
            usleep(10000);
        }
        
        $this->info("Success: $successCount, Failed/Conflict: $failCount");
        
        // Assert Database State
        $dispute->refresh();
        $this->info("Final Dispute Status: " . $dispute->status);
        $this->info("Buyer Balance: " . $buyer->fresh()->balance);
        $this->info("Seller Balance: " . $seller->fresh()->balance);
    }
}
