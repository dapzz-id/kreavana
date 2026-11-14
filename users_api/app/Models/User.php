<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Tymon\JWTAuth\Contracts\JWTSubject;
use Illuminate\Foundation\Auth\User as Authenticatable;

class User extends Authenticatable implements JWTSubject
{
    use HasFactory, HasUuids, SoftDeletes;

    protected $fillable = [
        'username',
        'email',
        'phone',
        'full_name',
        'display_name',
        'avatar_url',
        'date_of_birth',
        'gender',
        'locale',
        'timezone',
        'is_active',
        'is_suspended',
        'last_login_at',
    ];

    protected $casts = [
        'date_of_birth' => 'date',
        'is_active' => 'boolean',
        'is_suspended' => 'boolean',
        'last_login_at' => 'datetime',
    ];

    public function credential()
    {
        return $this->hasOne(UserCredential::class);
    }

    public function sessions()
    {
        return $this->hasMany(UserSession::class);
    }

    public function devices()
    {
        return $this->hasMany(UserDevice::class);
    }

    public function kyc()
    {
        return $this->hasOne(UserKyc::class);
    }

    public function addresses()
    {
        return $this->hasMany(UserAddress::class);
    }

    /**
     * Get the identifier stored in JWT Subject claim.
     */
    public function getJWTIdentifier()
    {
        return $this->getKey();
    }

    /**
     * Custom claims for JWT Access Token (Universal Identity Token).
     */
    public function getJWTCustomClaims(): array
    {
        return [
            'username' => $this->username,
            'email' => $this->email,
            'full_name' => $this->full_name,
            'avatar_url' => $this->avatar_url,
            'is_kyc_verified' => $this->kyc?->status === 'approved',
            'locale' => $this->locale,
        ];
    }
}
