<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\CreatorRecommendationService;
use App\Traits\ApiResponse;

class RecommendationController extends Controller
{
    use ApiResponse;

    protected CreatorRecommendationService $recommendationService;

    public function __construct(CreatorRecommendationService $recommendationService)
    {
        $this->recommendationService = $recommendationService;
    }

    public function getCreatorRecommendations(Request $request)
    {
        // Strictly ignore any metric parameters from client
        $filters = $request->only([
            'sub_role',
            'category',
            'region',
            'start_date',
            'end_date'
        ]);

        $page = (int) $request->input('page', 1);
        $perPage = (int) $request->input('per_page', 20);

        if ($page < 1) {
            return $this->errorResponse('Invalid page parameter.', 422);
        }
        if ($perPage < 1 || $perPage > 50) {
            return $this->errorResponse('per_page must be between 1 and 50.', 422);
        }

        if (!empty($filters['sub_role'])) {
            $enum = \App\Enums\CreatorSubRole::tryFrom($filters['sub_role']);
            if (!$enum) {
                return $this->errorResponse('Invalid sub_role provided.', 422);
            }
        }

        if (!empty($filters['start_date']) && !empty($filters['end_date'])) {
            if (strtotime($filters['start_date']) > strtotime($filters['end_date'])) {
                return $this->errorResponse('start_date cannot be after end_date.', 422);
            }
        } else if (!empty($filters['start_date']) || !empty($filters['end_date'])) {
            return $this->errorResponse('Both start_date and end_date must be provided for availability filtering.', 422);
        }

        $paginator = $this->recommendationService->getRecommendations($filters, $page, $perPage);

        // Format response
        $data = collect($paginator->items())->map(function ($creator) {
            return [
                'id' => $creator->id,
                'name' => $creator->name,
                'username' => $creator->username,
                'avatar_url' => $creator->avatar_url,
                'sub_role' => is_string($creator->sub_role) ? $creator->sub_role : $creator->sub_role?->value,
                'performance_boost' => $creator->performance_boost,
                'positive_marketplace_reviews_count' => $creator->positive_marketplace_reviews_count,
                'positive_contract_reviews_count' => $creator->positive_contract_reviews_count,
                'rating' => round($creator->rating, 2),
                // Expose basic service categories
                'service_categories' => $creator->creatorServices
                    ->where('status', 'active')
                    ->pluck('category')
                    ->unique()
                    ->values()
                    ->all()
            ];
        });

        $isAvailabilityFiltering = !empty($filters['start_date']) && !empty($filters['end_date']);

        return response()->json([
            'status' => true,
            'message' => 'Creator recommendations retrieved successfully.',
            'data' => $data->toArray(),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'per_page' => $paginator->perPage(),
                'total' => $isAvailabilityFiltering ? null : $paginator->total(),
                'last_page' => $isAvailabilityFiltering ? null : $paginator->lastPage(),
                'has_more' => $isAvailabilityFiltering ? ($data->count() === $perPage) : $paginator->hasMorePages(),
            ]
        ], 200);
    }

    public function getServiceCategories()
    {
        $categories = \App\Models\CreatorService::where('status', 'active')
            ->pluck('category')
            ->filter()
            ->unique()
            ->values();

        return response()->json([
            'status' => true,
            'message' => 'Service categories retrieved successfully.',
            'data' => $categories
        ], 200);
    }
}
