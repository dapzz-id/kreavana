<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Pagination\LengthAwarePaginator;
use App\Enums\CreatorSubRole;
use Carbon\Carbon;

class CreatorRecommendationService
{
    protected CreatorAvailabilityService $availabilityService;

    public function __construct(CreatorAvailabilityService $availabilityService)
    {
        $this->availabilityService = $availabilityService;
    }

    public function getRecommendations(array $filters = [], int $page = 1, int $perPage = 20): LengthAwarePaginator
    {
        $query = User::query()
            ->where('role', \App\Enums\RoleType::Creator)
            ->where('is_creator_approved', true);

        // Eager load marketplace items to avoid N+1 when retrieving categories
        $query->with(['marketplaceItems' => function ($q) {
            $q->where('delivery_type', 'service')
              ->where('status', 'published');
        }]);

        // 1. Service Catalog Filter (Mandatory)
        $query->whereHas('marketplaceItems', function ($q) use ($filters) {
            $q->where('delivery_type', 'service')
              ->where('status', 'published');

            if (!empty($filters['category'])) {
                $q->where('category', $filters['category']);
            }
        });

        // 2. Sub-Role Filter
        if (!empty($filters['sub_role'])) {
            $query->where('sub_role', $filters['sub_role']);
        }

        // 3. Region Filter
        if (!empty($filters['region'])) {
            $query->whereHas('addresses', function ($q) use ($filters) {
                $q->where('is_default', true)
                  ->where('city', $filters['region']);
            });
        }

        // Add counts for ranking
        // Positive Marketplace Reviews (Digital Downloads + Rating > 4)
        $query->withCount(['marketplaceReviews as positive_marketplace_reviews_count' => function ($q) {
            $q->where('marketplace_reviews.rating', '>', 4)
              ->whereHas('item', function ($sq) {
                  $sq->where('delivery_type', 'digital_download');
              });
            // We assume MarketplaceReview only exists for successful purchases.
        }]);

        // Positive Contract Reviews
        // Based on OpportunityReview where related JobContract is completed
        $query->addSelect([
            'positive_contract_reviews_count' => \App\Models\OpportunityReview::selectRaw('count(*)')
                ->whereColumn('creator_id', 'users.id')
                ->where('opportunity_reviews.rating', '>', 4)
                ->whereExists(function ($sq) {
                    $sq->select(\Illuminate\Support\Facades\DB::raw(1))
                       ->from('job_contracts')
                       ->whereColumn('job_contracts.opportunity_id', 'opportunity_reviews.opportunity_id')
                       ->whereColumn('job_contracts.creator_id', 'users.id')
                       ->where('job_contracts.work_status', 'completed');
                })
        ]);

        // Rating average fallback
        $query->addSelect([
            'rating' => \App\Models\OpportunityReview::selectRaw('COALESCE(avg(opportunity_reviews.rating), 0)')
                ->whereColumn('creator_id', 'users.id')
        ]);

        // Deterministic Ranking
        $query->orderBy('performance_boost', 'desc')
              ->orderBy('positive_marketplace_reviews_count', 'desc')
              ->orderBy('positive_contract_reviews_count', 'desc')
              ->orderBy('rating', 'desc')
              ->orderBy('id', 'asc');

        // 4. Availability Filter
        if (!empty($filters['start_date']) && !empty($filters['end_date'])) {
            $startDate = Carbon::parse($filters['start_date']);
            $endDate = Carbon::parse($filters['end_date']);

            // FALSE POSITIVE SAFE PRE-FILTER:
            // Eliminate creators who we can definitively prove are unavailable.
            // A creator is unavailable if their `max_work_capacity` is 0 and they do NOT have 
            // any schedules in the requested date range that sets them to be available.
            // (Note: To be completely false-positive safe, we only exclude if max_capacity = 0 AND no schedules exist).
            $query->where(function ($q) use ($startDate, $endDate) {
                $q->where('max_work_capacity', '>', 0)
                  ->orWhereExists(function ($sq) use ($startDate, $endDate) {
                      $sq->select(\Illuminate\Support\Facades\DB::raw(1))
                         ->from('creator_capacity_schedules')
                         ->whereColumn('creator_capacity_schedules.creator_id', 'users.id')
                         ->whereDate('date', '>=', $startDate->format('Y-m-d'))
                         ->whereDate('date', '<=', $endDate->format('Y-m-d'))
                         ->where('is_unavailable', false);
                  });
            });

            $availableCreators = collect();
            $offset = 0;
            $batchSize = $perPage * 2; // Fetch twice the perPage to reduce query roundtrips
            $targetOffset = ($page - 1) * $perPage;
            $collectedForPreviousPages = 0;

            // Total base creators (ignores availability) - allows metadata to be created without 
            // evaluating availability for the entire database.
            $totalBaseCreators = $query->count();

            while ($availableCreators->count() < $perPage) {
                // Fetch batch
                $batch = (clone $query)->offset($offset)->limit($batchSize)->get();

                if ($batch->isEmpty()) {
                    break;
                }

                foreach ($batch as $creator) {
                    try {
                        $availability = $this->availabilityService->validateDateRangeCapacity($creator, $startDate, $endDate);
                        $isAvailable = $availability['available'] ?? true;
                    } catch (\Exception $e) {
                        $isAvailable = false;
                    }

                    if ($isAvailable) {
                        if ($collectedForPreviousPages < $targetOffset) {
                            $collectedForPreviousPages++;
                        } else {
                            $availableCreators->push($creator);
                            if ($availableCreators->count() >= $perPage) {
                                break;
                            }
                        }
                    }
                }

                $offset += $batchSize;
            }

            return new LengthAwarePaginator(
                $availableCreators,
                $totalBaseCreators,
                $perPage,
                $page
            );
        }

        return $query->paginate($perPage, ['*'], 'page', $page);
    }
}
