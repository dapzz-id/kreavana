<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class UserKyc extends Model
{
    use HasFactory, HasUuids;

    protected $table = 'user_kyc';

    protected $fillable = [
        'user_id',
        'nik',
        'full_name_ktp',
        'ktp_photo_url',
        'selfie_photo_url',
        'nib_number',
        'nib_file_url',
        'verification_type',
        'status',
        'rejection_reason',
        'submitted_at',
        'verified_at',
        'verified_by',
    ];

    protected $casts = [
        'submitted_at' => 'datetime',
        'verified_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
