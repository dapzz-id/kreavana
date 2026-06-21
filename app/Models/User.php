<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\Storage;

#[Fillable(['name', 'username', 'email', 'password', 'role_id', 'google_id', 'bio', 'profile_photo_path', 'website', 'face_embeddings', 'latitude', 'longitude'])]
#[Hidden(['password', 'remember_token', 'face_embeddings'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable;

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password'          => 'hashed',
            'face_embeddings'   => 'array',
        ];
    }

    // ─── Accessors ──────────────────────────────────────────────────────────

    /**
     * Get a displayable profile photo URL.
     */
    public function getProfilePhotoUrlAttribute(): string
    {
        if ($this->profile_photo_path && Storage::disk('public')->exists($this->profile_photo_path)) {
            return Storage::url($this->profile_photo_path);
        }

        return 'https://ui-avatars.com/api/?name=' . urlencode($this->name) . '&background=1e293b&color=a5b4fc&bold=true&size=128';
    }

    /**
     * Dynamic Balance Accessor (reads and decodes secure ledger entries)
     */
    public function getBalanceAttribute(): float
    {
        return app(\App\Services\LedgerService::class)->getBalance($this);
    }

    // ─── Relationships ───────────────────────────────────────────────────────

    public function role()
    {
        return $this->belongsTo(Role::class);
    }

    public function photographerRequests()
    {
        return $this->hasMany(PhotographerRequest::class);
    }

    public function photos()
    {
        return $this->hasMany(Photo::class);
    }

    public function stories()
    {
        return $this->hasMany(Story::class);
    }

    public function likes()
    {
        return $this->hasMany(Like::class);
    }

    public function comments()
    {
        return $this->hasMany(Comment::class);
    }

    public function savedPhotos()
    {
        return $this->hasMany(SavedPhoto::class);
    }

    public function purchases()
    {
        return $this->hasMany(Purchase::class);
    }

    public function ledgerEntries()
    {
        return $this->hasMany(Ledger::class);
    }

    public function followers()
    {
        return $this->belongsToMany(User::class, 'followers', 'user_id', 'follower_id');
    }

    public function following()
    {
        return $this->belongsToMany(User::class, 'followers', 'follower_id', 'user_id');
    }

    /**
     * Messages sent by this user
     */
    public function sentMessages()
    {
        return $this->hasMany(Message::class, 'sender_id');
    }

    /**
     * Messages received by this user
     */
    public function receivedMessages()
    {
        return $this->hasMany(Message::class, 'receiver_id');
    }

    // ─── Role Helpers ────────────────────────────────────────────────────────

    public function hasRole(string $roleSlug): bool
    {
        return $this->role && $this->role->slug === $roleSlug;
    }

    public function isSuperadmin(): bool { return $this->hasRole('superadmin'); }
    public function isPhotographer(): bool { return $this->hasRole('photographer'); }
    public function isUser(): bool { return $this->hasRole('user'); }

    // ─── Business Logic ──────────────────────────────────────────────────────

    /**
     * Check if a user has purchased a photo
     */
    public function hasPurchased(int $photoId): bool
    {
        $photo = Photo::find($photoId);
        if ($photo && $photo->user_id === $this->id) return true;
        if ($this->isSuperadmin()) return true;

        return $this->purchases()
            ->where('photo_id', $photoId)
            ->where('payment_status', 'completed')
            ->exists();
    }

    /**
     * Count unread messages
     */
    public function unreadMessageCount(): int
    {
        return Message::where('receiver_id', $this->id)->whereNull('read_at')->count();
    }

    /**
     * Get distinct conversations (list of people this user has DM'd with)
     */
    public function conversations()
    {
        $sent = $this->sentMessages()->select('receiver_id as partner_id')->distinct();
        $received = $this->receivedMessages()->select('sender_id as partner_id')->distinct();

        return $sent->union($received);
    }
}
