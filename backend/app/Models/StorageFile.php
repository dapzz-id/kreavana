<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class StorageFile extends Model
{
    use HasFactory, HasUuids, SoftDeletes;

    protected $fillable = [
        'user_id',
        'original_name',
        'stored_name',
        'disk',
        'path',
        'category',
        'visibility',
        'mime_type',
        'size',
        'checksum',
        'source_type',
        'source_storage_file_id',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
