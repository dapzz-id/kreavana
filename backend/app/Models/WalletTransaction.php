<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable([
    'user_id',
    'type',
    'amount',
    'fee',
    'payment_method',
    'payment_provider',
    'status',
    'reference_number',
    'description',
])]
class WalletTransaction extends Model
{
    /**
     * Get the user that owns the transaction.
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
