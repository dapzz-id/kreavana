<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PresenceChannel;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class MessageSent implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $message;
    public $chatId;
    public array $participantIds;

    /**
     * Create a new event instance.
     */
    public function __construct($message, $chatId, array $participantIds = [])
    {
        $this->message = $message;
        $this->chatId = $chatId;
        $this->participantIds = $participantIds;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, Channel>
     */
    public function broadcastOn(): array
    {
        $channels = [
            new Channel('chat.' . $this->chatId),
        ];

        foreach ($this->participantIds as $participantId) {
            if (!empty($participantId)) {
                $channels[] = new Channel('user.' . $participantId);
            }
        }

        return $channels;
    }

    public function broadcastAs()
    {
        return 'message.sent';
    }
}
