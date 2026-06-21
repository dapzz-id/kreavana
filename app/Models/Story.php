<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['user_id', 'file_path', 'type', 'caption', 'expires_at'])]
class Story extends Model
{
    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function views()
    {
        return $this->hasMany(StoryView::class);
    }

    public function isExpired(): bool
    {
        return $this->expires_at->isPast();
    }

    /**
     * Scope: only active (non-expired) stories
     */
    public function scopeActive($query)
    {
        return $query->where('expires_at', '>', now());
    }
}
