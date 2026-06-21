<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['user_id', 'photo_id', 'amount', 'payment_status', 'midtrans_transaction_id'])]
class Purchase extends Model
{
    use HasFactory;

    protected function casts(): array
    {
        return [
            'amount' => 'float',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function photo()
    {
        return $this->belongsTo(Photo::class);
    }
}
