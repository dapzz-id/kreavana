<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class StorageFileReference extends Model
{
    use HasUuids;

    protected $fillable = [
        'storage_file_id',
        'owner_type',
        'owner_id',
        'reference_type',
        'reference_id',
    ];
}
