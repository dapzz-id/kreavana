<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class MessageKey extends Model
{
    use HasUuids;

    protected $fillable = [
        'message_id',
        'device_id',
        'encrypted_key',
    ];

    public function message()
    {
        return $this->belongsTo(Message::class);
    }

    public function device()
    {
        return $this->belongsTo(UserDevice::class, 'device_id');
    }
}
