<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['user_id', 'title', 'description', 'original_path', 'watermarked_path', 'price', 'is_for_sale', 'tags'])]
class Photo extends Model
{
    use HasFactory;

    protected function casts(): array
    {
        return [
            'price' => 'float',
            'is_for_sale' => 'boolean',
        ];
    }

    /**
     * Relationship with the Photographer (User)
     */
    public function photographer()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /**
     * Relationship with Likes
     */
    public function likes()
    {
        return $this->hasMany(Like::class);
    }

    /**
     * Relationship with Comments
     */
    public function comments()
    {
        return $this->hasMany(Comment::class);
    }

    /**
     * Relationship with Saved Photos
     */
    public function savedBy()
    {
        return $this->hasMany(SavedPhoto::class);
    }

    /**
     * Relationship with Purchases
     */
    public function purchases()
    {
        return $this->hasMany(Purchase::class);
    }

    /**
     * Helper to check if a photo is free
     */
    public function getIsFreeAttribute(): bool
    {
        return !$this->is_for_sale || $this->price <= 0;
    }
}
