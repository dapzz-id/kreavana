<?php

namespace App\Services;

use App\Models\User;
use App\Models\JobContract;
use App\Models\CreatorCapacitySchedule;
use Carbon\CarbonInterface;
use Carbon\Carbon;
use Exception;

class CreatorAvailabilityService extends BaseService
{
    /**
     * Active work statuses that consume capacity
     */
    protected const ACTIVE_WORK_STATUSES = [
        'scheduled',
        'in_progress',
        'review',
        'revision',
    ];

    /**
     * Active contract statuses that consume capacity
     */
    protected const ACTIVE_CONTRACT_STATUSES = [
        'approved',
        'escrow_paid',
        'cancel_requested',
        'disputed',
    ];

    /**
     * Get the global active job count for the creator.
     */
    public function getActiveJobCount(User $creator): int
    {
        return JobContract::where('creator_id', $creator->id)
            ->whereIn('contract_status', self::ACTIVE_CONTRACT_STATUSES)
            ->whereIn('work_status', self::ACTIVE_WORK_STATUSES)
            ->count();
    }

    /**
     * Get global availability status based on current active jobs vs global capacity.
     */
    public function getAvailabilityStatus(User $creator): array
    {
        $maxCapacity = $creator->max_work_capacity;
        $activeWorkCount = $this->getActiveJobCount($creator);

        return [
            'max_work_capacity' => $maxCapacity,
            'active_work_count' => $activeWorkCount,
            'remaining_capacity' => $maxCapacity === null ? null : max(0, $maxCapacity - $activeWorkCount),
            'availability_status' => $this->calculateStatusLabel($maxCapacity, $activeWorkCount),
        ];
    }

    /**
     * Get availability for a specific date.
     */
    public function getAvailabilityForDate(User $creator, CarbonInterface $date): array
    {
        $dateStr = $date->format('Y-m-d');

        // Load override
        $override = CreatorCapacitySchedule::where('creator_id', $creator->id)
            ->whereDate('date', $dateStr)
            ->first();

        // Determine effective capacity
        $effectiveCapacity = $creator->max_work_capacity;
        $isWorkingDay = true;
        $notes = null;

        if ($override) {
            $notes = $override->notes;
            if ($override->is_unavailable) {
                $effectiveCapacity = 0;
                $isWorkingDay = false;
            } elseif ($override->max_capacity !== null) {
                $effectiveCapacity = $override->max_capacity;
            }
        } elseif ($effectiveCapacity === 0) {
            // Global paused
            $isWorkingDay = false;
        }

        // Calculate used capacity for this specific date
        $usedCapacity = JobContract::where('creator_id', $creator->id)
            ->whereIn('contract_status', self::ACTIVE_CONTRACT_STATUSES)
            ->whereIn('work_status', self::ACTIVE_WORK_STATUSES)
            ->whereDate('scheduled_start_date', '<=', $dateStr)
            ->whereDate('scheduled_end_date', '>=', $dateStr)
            ->count();

        $status = $isWorkingDay ? $this->calculateStatusLabel($effectiveCapacity, $usedCapacity) : 'Unavailable';

        return [
            'date' => $dateStr,
            'is_working_day' => $isWorkingDay,
            'effective_capacity' => $effectiveCapacity,
            'active_work_count' => $usedCapacity, // Same as used capacity conceptually per date
            'booking_count' => $usedCapacity,
            'used_capacity' => $usedCapacity,
            'remaining_capacity' => $effectiveCapacity === null ? null : max(0, $effectiveCapacity - $usedCapacity),
            'availability_status' => $status,
            'notes' => $notes,
        ];
    }

    /**
     * Get availability for a date range (inclusive).
     */
    public function getAvailabilityForDateRange(User $creator, CarbonInterface $start, CarbonInterface $end): array
    {
        if ($start->gt($end)) {
            throw new Exception("Start date cannot be after end date.", 400);
        }

        // Limit to max 60 days
        if ($start->diffInDays($end) > 60) {
            throw new Exception("Date range cannot exceed 60 days.", 400);
        }

        $days = [];
        $workingDays = 0;
        $unavailableDays = 0;
        $conflicts = [];

        $currentDate = $start->copy()->startOfDay();
        $endDate = $end->copy()->startOfDay();

        while ($currentDate->lte($endDate)) {
            $dayData = $this->getAvailabilityForDate($creator, $currentDate);
            
            $days[] = [
                'date' => $dayData['date'],
                'is_working_day' => $dayData['is_working_day'],
                'availability_status' => $dayData['availability_status'],
            ];

            if ($dayData['is_working_day']) {
                $workingDays++;
                if ($dayData['availability_status'] === 'Full') {
                    $conflicts[] = [
                        'date' => $dayData['date'],
                        'reason' => 'CAPACITY_FULL',
                        'remaining_capacity' => 0,
                    ];
                }
            } else {
                $unavailableDays++;
            }

            $currentDate->addDay();
        }

        $isAvailable = count($conflicts) === 0 && $workingDays > 0;

        return [
            'available' => $isAvailable,
            'working_days' => $workingDays,
            'unavailable_days' => $unavailableDays,
            'days' => $days,
            'conflicts' => count($conflicts) > 0 ? $conflicts : null,
        ];
    }

    /**
     * Validate date range capacity for booking. Throws 409 if conflict exists.
     */
    public function validateDateRangeCapacity(User $creator, CarbonInterface $start, CarbonInterface $end): void
    {
        $availability = $this->getAvailabilityForDateRange($creator, $start, $end);

        if ($availability['working_days'] === 0) {
            throw new Exception(json_encode([
                'error' => 'CREATOR_NO_WORKING_DATES',
                'message' => 'Tidak ada hari kerja yang tersedia pada periode yang dipilih.',
            ]), 409);
        }

        if (count($availability['conflicts'] ?? []) > 0) {
            throw new Exception(json_encode([
                'error' => 'CREATOR_CAPACITY_FULL',
                'message' => 'Creator tidak tersedia pada salah satu hari kerja yang dipilih (Kapasitas Penuh).',
                'conflicts' => $availability['conflicts'],
            ]), 409);
        }
    }

    /**
     * Calculate availability status label deterministically.
     */
    private function calculateStatusLabel(?int $capacity, int $used): string
    {
        if ($capacity === 0) {
            return 'Unavailable';
        }

        if ($capacity === null) {
            return 'Available';
        }

        if ($used >= $capacity) {
            return 'Full';
        }

        // Integer safe percentages
        if (($used * 100) >= ($capacity * 80)) {
            return 'Busy';
        }

        if (($used * 100) >= ($capacity * 50)) {
            return 'Limited';
        }

        return 'Available';
    }
}
