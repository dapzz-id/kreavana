<?php

namespace App\Services;

use App\Repositories\NotificationRepository;

class NotificationService extends BaseService
{
    protected NotificationRepository $notificationRepo;

    public function __construct(NotificationRepository $notificationRepo)
    {
        $this->notificationRepo = $notificationRepo;
    }

    public function getUserNotifications(string $userId)
    {
        return $this->notificationRepo->all()
            ->where('user_id', $userId)
            ->sortByDesc('created_at')
            ->values();
    }

    public function markAllAsRead(string $userId): void
    {
        $this->notificationRepo->all()
            ->where('user_id', $userId)
            ->where('is_read', false)
            ->each(function ($notification) {
                $notification->update(['is_read' => true]);
            });
    }
}
