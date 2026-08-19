<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

use Tymon\JWTAuth\Contracts\JWTSubject;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

#[Fillable(['name', 'username', 'email', 'password', 'avatar_url', 'phone', 'role', 'sub_role', 'is_creator_approved', 'max_work_capacity', 'balance', 'last_online', 'used_storage_bytes', 'public_key', 'performance_boost', 'email_verification_code_hash', 'email_verification_expires_at', 'email_verification_attempts'])]
#[Hidden(['password', 'remember_token', 'wallet_pin'])]
class User extends Authenticatable implements JWTSubject
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable, HasUuids;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'email_verification_expires_at' => 'datetime',
            'last_online' => 'datetime',
            'password' => 'hashed',
            'max_work_capacity' => 'integer',
            'role' => \App\Enums\RoleType::class,
        ];
    }

    protected function castAttribute($key, $value)
    {
        if ($key === 'sub_role') {
            return $value !== null ? \App\Enums\CreatorSubRole::tryFrom($value) : null;
        }
        return parent::castAttribute($key, $value);
    }

    public function getSubRoleLabelAttribute(): ?string
    {
        $enum = \App\Enums\CreatorSubRole::tryFrom($this->attributes['sub_role'] ?? '');
        return $enum?->label();
    }

    /**
     * Get the identifier that will be stored in the subject claim of the JWT.
     *
     * @return mixed
     */
    public function getJWTIdentifier()
    {
        return $this->getKey();
    }

    /**
     * Return a key value array, containing any custom claims to be added to the JWT.
     *
     * @return array
     */
    public function getSelectedSubRoleAttribute()
    {
        return $this->sub_role;
    }

    protected $appends = ['subscription_tier', 'storage_limit_bytes', 'max_voice_call_duration_seconds', 'max_video_call_duration_seconds', 'performance_boost', 'selected_sub_role'];

    public function getJWTCustomClaims()
    {
        return [
            'role' => $this->role->value,
            'permissions' => config('permissions.' . $this->role->value, []),
        ];
    }

    public function getSubscriptionTierAttribute()
    {
        $active = $this->activeSubscription;
        return $active ? $active->tier : 'free';
    }

    public function getStorageLimitBytesAttribute()
    {
        $tier = $this->subscription_tier;
        if ($tier === 'super') return 20 * 1024 * 1024 * 1024; // 20GB
        if ($tier === 'pro') return 10 * 1024 * 1024 * 1024; // 10GB
        if ($tier === 'plus') return 3 * 1024 * 1024 * 1024; // 3GB
        return 1 * 1024 * 1024 * 1024; // 1GB free
    }

    public function getMaxVoiceCallDurationSecondsAttribute()
    {
        $tier = $this->subscription_tier;
        if ($tier === 'super') return 7200;
        if ($tier === 'pro') return 6000;
        if ($tier === 'plus') return 4800;
        return 3600;
    }

    public function getMaxVideoCallDurationSecondsAttribute()
    {
        $tier = $this->subscription_tier;
        if ($tier === 'super') return 4500;
        if ($tier === 'pro') return 3600;
        if ($tier === 'plus') return 2700;
        return 1800;
    }

    public function getPerformanceBoostAttribute()
    {
        return (float) ($this->attributes['performance_boost'] ?? 0.0);
    }

    public function updatePerformanceBoost()
    {
        \Illuminate\Support\Facades\DB::transaction(function () {
            // Lock the user row for update to prevent concurrent lost updates
            $user = User::where('id', $this->id)->lockForUpdate()->first();

            $tier = $user->subscription_tier;
            $base = 1.0;
            if ($tier === 'super') $base = 5.0;
            elseif ($tier === 'pro') $base = 2.0;
            elseif ($tier === 'plus') $base = 1.5;

            $totalBonusPercentage = \App\Models\CreatorPerformanceEvent::where('user_id', $user->id)
                                    ->where('is_active', true)
                                    ->sum('bonus_percentage');

            $finalBoost = $totalBonusPercentage * $base;

            $user->update(['performance_boost' => $finalBoost]);
        });
    }

    public function subscriptions()
    {
        return $this->hasMany(Subscription::class);
    }

    public function activeSubscription()
    {
        return $this->hasOne(Subscription::class)->where(function ($q) {
            $q->whereNull('expires_at')->orWhere('expires_at', '>', now());
        })->latest();
    }

    public function userFiles()
    {
        return $this->hasMany(UserFile::class);
    }

    public function addresses()
    {
        return $this->hasMany(UserAddress::class);
    }

    public function marketplaceItems()
    {
        return $this->hasMany(MarketplaceItem::class);
    }

    public function creatorServices()
    {
        return $this->hasMany(CreatorService::class, 'creator_id');
    }

    public function jobContractsAsCreator()
    {
        return $this->hasMany(JobContract::class, 'creator_id');
    }

    public function marketplaceReviews()
    {
        return $this->hasManyThrough(MarketplaceReview::class, MarketplaceItem::class);
    }
}
