<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class DisputeCase extends Model
{
    use HasUuids;

    protected $fillable = [
        'case_type',
        'requester_id',
        'other_party_id',
        'assigned_admin_id',
        'marketplace_purchase_id',
        'opportunity_id',
        'chat_id',
        'reason',
        'status',
        'resolution',
    ];

    public function requester()
    {
        return $this->belongsTo(User::class, 'requester_id');
    }

    public function otherParty()
    {
        return $this->belongsTo(User::class, 'other_party_id');
    }

    public function assignedAdmin()
    {
        return $this->belongsTo(User::class, 'assigned_admin_id');
    }

    public function marketplacePurchase()
    {
        return $this->belongsTo(MarketplacePurchase::class, 'marketplace_purchase_id');
    }

    public function opportunity()
    {
        return $this->belongsTo(Opportunity::class, 'opportunity_id');
    }

    public function chat()
    {
        return $this->belongsTo(Chat::class, 'chat_id');
    }
}
