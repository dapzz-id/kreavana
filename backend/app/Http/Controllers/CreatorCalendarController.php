<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Models\CreatorCapacitySchedule;
use App\Traits\ApiResponse;
use Carbon\Carbon;
use Exception;

class CreatorCalendarController extends Controller
{
    use ApiResponse;

    public function index(Request $request)
    {
        $user = Auth::guard('api')->user();
        if ($user->role !== \App\Enums\RoleType::Creator && $user->role !== \App\Enums\RoleType::Admin) {
            return $this->errorResponse('Akses ditolak.', 403);
        }

        $schedules = CreatorCapacitySchedule::where('creator_id', $user->id)
            ->orderBy('date', 'asc')
            ->get();

        return $this->successResponse('Jadwal kreator berhasil diambil.', $schedules);
    }

    public function storeOrUpdate(Request $request)
    {
        $user = Auth::guard('api')->user();
        if ($user->role !== \App\Enums\RoleType::Creator && $user->role !== \App\Enums\RoleType::Admin) {
            return $this->errorResponse('Akses ditolak.', 403);
        }

        $validated = $request->validate([
            'date' => 'required|date',
            'max_capacity' => 'nullable|integer|min:0|max:10000',
            'is_unavailable' => 'required|boolean',
            'notes' => 'nullable|string',
        ]);

        // Normalize
        if ($validated['is_unavailable']) {
            $validated['max_capacity'] = null;
        }

        $date = Carbon::parse($validated['date'])->startOfDay();
        
        // Allowed to modify today and future
        if ($date->lt(Carbon::now()->startOfDay())) {
            return $this->errorResponse('Tidak dapat mengubah jadwal di masa lalu.', 400);
        }

        $schedule = CreatorCapacitySchedule::updateOrCreate(
            ['creator_id' => $user->id, 'date' => $validated['date']],
            [
                'max_capacity' => $validated['max_capacity'],
                'is_unavailable' => $validated['is_unavailable'],
                'notes' => $validated['notes'] ?? null,
            ]
        );

        return $this->successResponse('Jadwal berhasil disimpan.', $schedule);
    }

    public function destroy(string $dateStr)
    {
        $user = Auth::guard('api')->user();
        if ($user->role !== \App\Enums\RoleType::Creator && $user->role !== \App\Enums\RoleType::Admin) {
            return $this->errorResponse('Akses ditolak.', 403);
        }

        $date = Carbon::parse($dateStr)->startOfDay();
        if ($date->lt(Carbon::now()->startOfDay())) {
            return $this->errorResponse('Tidak dapat menghapus jadwal di masa lalu.', 400);
        }

        CreatorCapacitySchedule::where('creator_id', $user->id)
            ->where('date', $dateStr)
            ->delete();

        return $this->successResponse('Jadwal berhasil dihapus.');
    }
}
