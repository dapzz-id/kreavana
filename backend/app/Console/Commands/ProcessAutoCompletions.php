<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\MarketplacePurchase;
use App\Models\Opportunity;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class ProcessAutoCompletions extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'transactions:auto-complete';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Process automatic completions for marketplace and opportunities';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $this->processMarketplace();
        $this->processOpportunities();
        $this->info('Auto completions processed.');
    }

    private function processMarketplace()
    {
        // Marketplace: creator_completed = true, buyer_completed = false, 3 days elapsed
        $purchases = MarketplacePurchase::where('creator_completed', true)
            ->where('buyer_completed', false)
            ->where('status', '!=', 'refunded')
            ->where('creator_completed_at', '<=', Carbon::now()->subDays(3))
            ->get();

        foreach ($purchases as $purchase) {
            DB::transaction(function () use ($purchase) {
                // Lock row
                $lockedPurchase = MarketplacePurchase::where('id', $purchase->id)->lockForUpdate()->first();
                
                // Double check condition under lock
                if ($lockedPurchase && 
                    $lockedPurchase->creator_completed && 
                    !$lockedPurchase->buyer_completed && 
                    $lockedPurchase->status !== 'refunded' &&
                    $lockedPurchase->creator_completed_at <= Carbon::now()->subDays(3)) {
                        
                    $lockedPurchase->buyer_completed = true;
                    // existing marketplace completion settlement would normally go here if implemented fully
                    // $lockedPurchase->status = 'completed'; // If that is the status used
                    $lockedPurchase->save();
                    
                    $this->info("Marketplace auto-completed: " . $lockedPurchase->id);
                }
            });
        }
    }

    private function processOpportunities()
    {
        // Normal Opportunities: creator_completed = true, buyer_completed = false, 1 month after deadline
        $opportunities = Opportunity::where('creator_completed', true)
            ->where('buyer_completed', false)
            ->where('status', '!=', 'closed')
            ->where('status', '!=', 'cancelled')
            // Deadline + 1 month passed. (Assuming deadline is a date)
            // MySQL: DATE_ADD(deadline, INTERVAL 1 MONTH) <= NOW()
            ->whereRaw("DATE_ADD(deadline, INTERVAL 1 MONTH) <= NOW()")
            ->get();

        foreach ($opportunities as $opp) {
            DB::transaction(function () use ($opp) {
                // Lock row
                $lockedOpp = Opportunity::where('id', $opp->id)->lockForUpdate()->first();
                
                // Double check condition under lock
                if ($lockedOpp && 
                    $lockedOpp->creator_completed && 
                    !$lockedOpp->buyer_completed && 
                    $lockedOpp->status !== 'closed' && 
                    $lockedOpp->status !== 'cancelled') {
                    
                    // Note: In PHP we can accurately check the deadline again
                    $deadlinePlusMonth = Carbon::parse($lockedOpp->deadline)->addMonth();
                    if (now()->greaterThanOrEqualTo($deadlinePlusMonth)) {
                        $lockedOpp->buyer_completed = true;
                        $lockedOpp->status = 'closed';
                        $lockedOpp->save();
                        
                        $this->info("Opportunity auto-completed: " . $lockedOpp->id);
                    }
                }
            });
        }
    }
}
