<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\User;
use App\Services\CreatorAvailabilityService;
use App\Traits\ApiResponse;
use Carbon\Carbon;
use Exception;

class CreatorAvailabilityController extends Controller
{
    use ApiResponse;

    protected CreatorAvailabilityService $availabilityService;

    public function __construct(CreatorAvailabilityService $availabilityService)
    {
        $this->availabilityService = $availabilityService;
    }

    public function getAvailability(Request $request, string $creatorId)
    {
        $creator = User::where('id', $creatorId)->where('role', \App\Enums\RoleType::Creator)->first();
        if (!$creator) {
            return $this->errorResponse('Kreator tidak ditemukan.', 404);
        }

        $startDateStr = $request->query('start_date');
        $endDateStr = $request->query('end_date');
        $dateStr = $request->query('date');

        try {
            if ($startDateStr && $endDateStr) {
                $start = Carbon::parse($startDateStr);
                $end = Carbon::parse($endDateStr);
                $data = $this->availabilityService->getAvailabilityForDateRange($creator, $start, $end);
                return $this->successResponse('Ketersediaan berhasil diambil.', $data);
            } elseif ($dateStr) {
                $date = Carbon::parse($dateStr);
                $data = $this->availabilityService->getAvailabilityForDate($creator, $date);
                return $this->successResponse('Ketersediaan berhasil diambil.', $data);
            } else {
                // Return global availability
                $data = $this->availabilityService->getAvailabilityStatus($creator);
                return $this->successResponse('Ketersediaan global berhasil diambil.', $data);
            }
        } catch (Exception $e) {
            $code = $e->getCode() ?: 500;
            if ($code < 100 || $code > 599) $code = 500;
            return $this->errorResponse($e->getMessage(), $code);
        }
    }
}
