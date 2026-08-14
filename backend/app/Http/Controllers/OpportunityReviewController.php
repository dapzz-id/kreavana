<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Opportunity;
use App\Models\OpportunityReview;
use App\Models\CreatorPerformanceEvent;
use Illuminate\Support\Facades\DB;
use App\Traits\ApiResponse;

class OpportunityReviewController extends Controller
{
    use ApiResponse;

    public function store(Request $request, $opportunityId)
    {
        $request->validate([
            'creator_id' => 'required|uuid|exists:users,id',
            'rating' => 'required|numeric|min:1.0|max:5.0',
            'comment' => 'nullable|string|max:1000',
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

            // Check for existing review with locking
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
                'reviewer_id' => $request->user()->id,
                'creator_id' => $request->creator_id,
                'rating' => $request->rating,
                'comment' => $request->comment,
            ]);

            if ($review->rating >= 4.0) {
                CreatorPerformanceEvent::firstOrCreate(
                    [
                        'user_id' => $review->creator_id,
                        'event_type' => 'project_rating',
                        'reference_id' => $review->id,
                    ],
                    [
                        'bonus_percentage' => 1.0,
                        'is_active' => true,
                    ]
                );

                $review->creator->updatePerformanceBoost();
            }

            return $this->successResponse('Review submitted successfully.', $review->toArray());
        });
    }
}
