<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Opportunity;
use App\Models\OpportunityReview;
use App\Models\MarketplaceReview;
use App\Models\MarketplaceItem;
use App\Models\CreatorPerformanceEvent;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use App\Traits\ApiResponse;

class OpportunityReviewController extends Controller
{
    use ApiResponse;

    public function store(Request $request, $opportunityId)
    {
        $request->validate([
            'creator_id'    => 'required|uuid|exists:users,id',
            'rating'        => 'required|numeric|min:1.0|max:5.0',
            'comment'       => 'nullable|string|max:1000',
            'is_on_time'    => 'nullable|boolean',
            'delivery_days' => 'nullable|integer|min:0',
        ]);

        return DB::transaction(function () use ($request, $opportunityId) {
            $opportunity = Opportunity::lockForUpdate()->find($opportunityId);

            if (!$opportunity) {
                return $this->errorResponse('Opportunity not found.', 404);
            }

            if ($opportunity->status !== 'closed') {
                return $this->errorResponse('You can only review completed opportunities.', 400);
            }

            if ($opportunity->posted_by !== $request->user()->id) {
                return $this->errorResponse('Unauthorized to review this opportunity.', 403);
            }

            $existingReview = OpportunityReview::where('opportunity_id', $opportunityId)
                ->where('reviewer_id', $request->user()->id)
                ->where('creator_id', $request->creator_id)
                ->lockForUpdate()
                ->first();

            if ($existingReview) {
                return $this->errorResponse('You have already reviewed this creator for this opportunity.', 400);
            }

            $review = OpportunityReview::create([
                'opportunity_id' => $opportunity->id,
                'reviewer_id'    => $request->user()->id,
                'creator_id'     => $request->creator_id,
                'rating'         => $request->rating,
                'is_on_time'     => $request->has('is_on_time') ? (bool) $request->is_on_time : null,
                'delivery_days'  => $request->delivery_days,
                'comment'        => $request->comment,
            ]);

            if ($review->rating > 4.0) {
                CreatorPerformanceEvent::firstOrCreate(
                    [
                        'user_id'      => $review->creator_id,
                        'event_type'   => 'project_rating',
                        'reference_id' => $review->id,
                    ],
                    [
                        'bonus_percentage' => 1.0,
                        'is_active'        => true,
                    ]
                );

                $review->creator->updatePerformanceBoost();
            }

            return $this->successResponse('Review submitted successfully.', $review->toArray());
        });
    }

    public function listCreatorReviews(Request $request, $creatorId)
    {
        $perPage = (int) $request->input('per_page', 15);

        $oppReviews = OpportunityReview::with(['reviewer:id,name,avatar_url,sub_role'])
            ->where('creator_id', $creatorId)
            ->selectRaw("
                id,
                creator_id,
                reviewer_id,
                opportunity_id as reference_id,
                rating,
                is_on_time,
                delivery_days,
                comment,
                created_at,
                'opportunity' as source
            ");

        $marketplaceReviews = MarketplaceReview::with(['user:id,name,avatar_url,sub_role'])
            ->join('marketplace_items', 'marketplace_reviews.marketplace_item_id', '=', 'marketplace_items.id')
            ->where('marketplace_items.user_id', $creatorId)
            ->selectRaw("
                marketplace_reviews.id,
                marketplace_items.user_id as creator_id,
                marketplace_reviews.user_id as reviewer_id,
                marketplace_reviews.marketplace_item_id as reference_id,
                CAST(marketplace_reviews.rating AS DECIMAL(3,2)) as rating,
                NULL as is_on_time,
                NULL as delivery_days,
                marketplace_reviews.comment,
                marketplace_reviews.created_at,
                'marketplace' as source
            ");

        $union = $oppReviews->union($marketplaceReviews);

        $reviews = DB::table(DB::raw("({$union->toSql()}) as combined"))
            ->mergeBindings($union->getQuery())
            ->orderByDesc('combined.created_at')
            ->paginate($perPage);

        $reviewerIds = collect($reviews->items())->pluck('reviewer_id')->unique()->values();
        $reviewers = User::whereIn('id', $reviewerIds)
            ->get(['id', 'name', 'avatar_url', 'sub_role'])
            ->keyBy('id');

        $items = collect($reviews->items())->map(function ($row) use ($reviewers) {
            $row = (array) $row;
            $row['reviewer'] = $reviewers->get($row['reviewer_id']);
            $row['rating'] = (float) $row['rating'];
            $row['is_on_time'] = is_null($row['is_on_time']) ? null : (bool) $row['is_on_time'];
            $row['delivery_days'] = is_null($row['delivery_days']) ? null : (int) $row['delivery_days'];
            return $row;
        })->values();

        return response()->json([
            'status' => true,
            'data'   => [
                'items'      => $items,
                'pagination' => [
                    'total'        => $reviews->total(),
                    'per_page'     => $reviews->perPage(),
                    'current_page' => $reviews->currentPage(),
                    'last_page'    => $reviews->lastPage(),
                    'has_more'     => $reviews->hasMorePages(),
                ],
            ],
        ]);
    }

    public function getCreatorReviewSummary($creatorId)
    {
        User::findOrFail($creatorId);

        $oppStats = DB::table('opportunity_reviews')
            ->where('creator_id', $creatorId)
            ->selectRaw("
                COUNT(*) as total,
                COALESCE(AVG(rating), 0) as avg_rating,
                SUM(CASE WHEN is_on_time = 1 THEN 1 ELSE 0 END) as on_time_count,
                SUM(CASE WHEN is_on_time IS NOT NULL THEN 1 ELSE 0 END) as on_time_eligible,
                SUM(CASE WHEN rating >= 4.5 THEN 1 ELSE 0 END) as r5,
                SUM(CASE WHEN rating >= 3.5 AND rating < 4.5 THEN 1 ELSE 0 END) as r4,
                SUM(CASE WHEN rating >= 2.5 AND rating < 3.5 THEN 1 ELSE 0 END) as r3,
                SUM(CASE WHEN rating >= 1.5 AND rating < 2.5 THEN 1 ELSE 0 END) as r2,
                SUM(CASE WHEN rating < 1.5 THEN 1 ELSE 0 END) as r1
            ")
            ->first();

        $mpStats = DB::table('marketplace_reviews')
            ->join('marketplace_items', 'marketplace_reviews.marketplace_item_id', '=', 'marketplace_items.id')
            ->where('marketplace_items.user_id', $creatorId)
            ->selectRaw("
                COUNT(*) as total,
                COALESCE(AVG(marketplace_reviews.rating), 0) as avg_rating,
                SUM(CASE WHEN marketplace_reviews.rating >= 5 THEN 1 ELSE 0 END) as r5,
                SUM(CASE WHEN marketplace_reviews.rating = 4 THEN 1 ELSE 0 END) as r4,
                SUM(CASE WHEN marketplace_reviews.rating = 3 THEN 1 ELSE 0 END) as r3,
                SUM(CASE WHEN marketplace_reviews.rating = 2 THEN 1 ELSE 0 END) as r2,
                SUM(CASE WHEN marketplace_reviews.rating <= 1 THEN 1 ELSE 0 END) as r1
            ")
            ->first();

        $oppTotal      = (int) ($oppStats->total ?? 0);
        $mpTotal       = (int) ($mpStats->total ?? 0);
        $grandTotal    = $oppTotal + $mpTotal;

        $weightedAvg = 0;
        if ($grandTotal > 0) {
            $oppSum = ((float) ($oppStats->avg_rating ?? 0)) * $oppTotal;
            $mpSum  = ((float) ($mpStats->avg_rating ?? 0)) * $mpTotal;
            $weightedAvg = ($oppSum + $mpSum) / $grandTotal;
        }

        $onTimePercentage = 100.0;
        $eligible = (int) ($oppStats->on_time_eligible ?? 0);
        if ($eligible > 0) {
            $onTimePercentage = round(((int) ($oppStats->on_time_count ?? 0)) / $eligible * 100, 1);
        } elseif ($grandTotal > 0) {
            $highRatingCount =
                ((int) ($oppStats->r5 ?? 0)) + ((int) ($oppStats->r4 ?? 0)) +
                ((int) ($mpStats->r5 ?? 0)) + ((int) ($mpStats->r4 ?? 0));
            $onTimePercentage = round(($highRatingCount / $grandTotal) * 100, 1);
        }

        $distribution = [
            5 => ((int) ($oppStats->r5 ?? 0)) + ((int) ($mpStats->r5 ?? 0)),
            4 => ((int) ($oppStats->r4 ?? 0)) + ((int) ($mpStats->r4 ?? 0)),
            3 => ((int) ($oppStats->r3 ?? 0)) + ((int) ($mpStats->r3 ?? 0)),
            2 => ((int) ($oppStats->r2 ?? 0)) + ((int) ($mpStats->r2 ?? 0)),
            1 => ((int) ($oppStats->r1 ?? 0)) + ((int) ($mpStats->r1 ?? 0)),
        ];

        return response()->json([
            'status' => true,
            'data'   => [
                'average_rating'     => round($weightedAvg, 2),
                'total_reviews'      => $grandTotal,
                'on_time_percentage' => $onTimePercentage,
                'distribution'       => $distribution,
                'breakdown'          => [
                    'opportunity_total' => $oppTotal,
                    'marketplace_total' => $mpTotal,
                ],
            ],
        ]);
    }
}
