<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class MarketplaceItem extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'user_id', 'title', 'description', 'category', 'price',
        'rating', 'review_count', 'order_count', 'image_url',
        'is_featured', 'is_active',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'rating' => 'decimal:2',
            'review_count' => 'integer',
            'order_count' => 'integer',
            'is_featured' => 'boolean',
            'is_active' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(MarketplaceReview::class, 'marketplace_item_id');
    }

    public function recalculateRating(): void
    {
        $stats = $this->reviews()->selectRaw('AVG(rating) as avg_rating, COUNT(*) as cnt')->first();
        $this->update([
            'rating' => round($stats->avg_rating ?? 0, 2),
            'review_count' => $stats->cnt ?? 0,
        ]);
    }

    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeFeatured($query)
    {
        return $query->where('is_featured', true);
    }

    public function scopeCategory($query, ?string $category)
    {
        if ($category && $category !== 'Semua') {
            return $query->where('category', $category);
        }
        return $query;
    }

    public function scopeSearch($query, ?string $search)
    {
        if ($search && trim($search) !== '') {
            $term = trim($search);
            return $query->where(function ($q) use ($term) {
                $q->where('title', 'like', "%{$term}%")
                  ->orWhere('description', 'like', "%{$term}%")
                  ->orWhere('category', 'like', "%{$term}%")
                  ->orWhereHas('user', fn($u) => $u->where('name', 'like', "%{$term}%"));
            });
        }
        return $query;
    }
}
