<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PaymentProvider extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'code', 'name', 'type', 'brand_color', 'logo_url',
        'fee_percent', 'fee_flat', 'min_amount', 'max_amount',
        'sort_order', 'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active'    => 'boolean',
            'fee_percent'  => 'decimal:2',
            'fee_flat'     => 'decimal:2',
            'min_amount'   => 'decimal:2',
            'max_amount'   => 'decimal:2',
            'sort_order'   => 'integer',
        ];
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeByType($query, string $type)
    {
        return $query->where('type', $type);
    }
}
