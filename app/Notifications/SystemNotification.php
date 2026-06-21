<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

class SystemNotification extends Notification
{
    use Queueable;

    public string $title;
    public string $message;
    public string $actionUrl;
    public string $type;

    /**
     * Create a new notification instance.
     */
    public function __construct(string $title, string $message, string $actionUrl, string $type)
    {
        $this->title = $title;
        $this->message = $message;
        $this->actionUrl = $actionUrl;
        $this->type = $type;
    }

    /**
     * Get the notification's delivery channels.
     */
    public function via($notifiable): array
    {
        return ['database'];
    }

    /**
     * Get the array representation of the notification.
     */
    public function toArray($notifiable): array
    {
        return [
            'title' => $this->title,
            'message' => $this->message,
            'action_url' => $this->actionUrl,
            'type' => $this->type,
        ];
    }
}
