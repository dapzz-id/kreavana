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

#[Fillable(['name', 'username', 'email', 'password', 'avatar_url', 'phone', 'role', 'sub_role', 'is_creator_approved', 'balance', 'last_online'])]
#[Hidden(['password', 'remember_token'])]
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
            'last_online' => 'datetime',
            'password' => 'hashed',
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
    public function getJWTCustomClaims()
    {
        return [
            'role' => $this->role,
            'permissions' => config('permissions.' . $this->role, []),
        ];
    }
}
