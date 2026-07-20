<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
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
    use HasUuids, HasFactory;

    /**
     * Get the user that owns the transaction.
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
