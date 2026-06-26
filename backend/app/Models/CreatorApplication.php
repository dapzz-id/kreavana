<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CreatorApplication extends Model
{
    public $timestamps = false;
    
    protected $fillable = [
        'user_id',
        'pihak_category',
        'skill_description',
        'portfolio_link',
        'experience',
        'ktp_photo_url',
        'selfie_photo_url',
        'nik',
        'full_name_ktp',
        'birth_place',
        'birth_date',
        'address_ktp',
        'status',
        'admin_note',
        'applied_at',
        'reviewed_at',
    ];

    protected $casts = [
        'applied_at' => 'datetime',
        'reviewed_at' => 'datetime',
        'birth_date' => 'date',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
