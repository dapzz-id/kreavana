<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class CallSignaling implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $receiverId;
    public $callerId;
    public $callId;
    public $type;
    public $data;

    /**
     * Create a new event instance.
     *
     * @param int $receiverId
     * @param int $callerId
     * @param string $callId
     * @param string $type offer, answer, candidate, reject, end
     * @param array $data
     */
    public function __construct($receiverId, $callerId, $callId, $type, $data = [])
    {
        $this->receiverId = $receiverId;
        $this->callerId = $callerId;
        $this->callId = $callId;
        $this->type = $type;
        $this->data = $data;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return \Illuminate\Broadcasting\Channel|array
     */
    public function broadcastOn()
    {
        // Broadcast specifically to the receiver's call channel
        return new Channel('call.' . $this->receiverId);
    }

    /**
     * The event's broadcast name.
     *
     * @return string
     */
    public function broadcastAs()
    {
        return 'call.signal';
    }

    /**
     * Get the data to broadcast.
     *
     * @return array
     */
    public function broadcastWith()
    {
        return [
            'caller_id' => $this->callerId,
            'receiver_id' => $this->receiverId,
            'call_id' => $this->callId,
            'type' => $this->type, // offer, answer, candidate, end, reject
            'data' => $this->data, // Contains SDP or ICE Candidate
        ];
    }
}
