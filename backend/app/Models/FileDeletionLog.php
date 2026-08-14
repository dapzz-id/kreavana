<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FileDeletionLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'storage_file_id',
        'deleted_by',
        'reason',
        'ip_address',
        'user_agent',
        'category',
        'file_size',
    ];

    public function storageFile()
    {
        return $this->belongsTo(StorageFile::class)->withTrashed();
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'deleted_by');
    }
}
