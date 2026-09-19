<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PortfolioItem extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'user_id',
        'title',
        'category',
        'description',
        'image_url',
        'sort_order',
        'event_date',
        'location',
        'source',
        'verification_status',
        'client_name',
    ];

    protected $casts = [
        'user_id' => 'string',
        'event_date' => 'date',
    ];

    public function getImageUrlAttribute($value)
    {
        if (!$value) {
            return null;
        }

        if (str_starts_with($value, 'http://') || str_starts_with($value, 'https://')) {
            return $value;
        }

        $filename = basename($value);
        return url('api/portfolio-assets/' . $filename);
    }
}
