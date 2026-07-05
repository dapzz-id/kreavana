<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Services\NotificationService;
use App\Traits\ApiResponse;

class NotificationController extends Controller
{
    use ApiResponse;

    protected NotificationService $notificationService;

    public function __construct(NotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }

    public function index()
    {
        $user = Auth::guard('api')->user();
        $notifications = $this->notificationService->getUserNotifications($user->id);

        return $this->successResponse('Notifikasi berhasil diambil', $notifications->toArray());
    }

    public function markAsRead(Request $request)
    {
        $user = Auth::guard('api')->user();
        $this->notificationService->markAllAsRead($user->id);

        return $this->successResponse('Semua notifikasi berhasil ditandai sudah dibaca');
    }
}
