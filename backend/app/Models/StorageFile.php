<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Support\Facades\Storage;

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

    protected $appends = [
        'url',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Accessor to get the accessible public or streaming URL for this storage file.
     */
    public function getUrlAttribute(): string
    {
        if ($this->visibility === 'private') {
            return url('/api/storage/' . $this->id . '/view');
        }

        if (in_array($this->disk, ['minio', 's3'], true)) {
            return Storage::disk($this->disk)->url($this->path);
        }

        if ($this->disk === 'public') {
            return Storage::disk('public')->url($this->path);
        }

        return url('/api/storage/' . $this->id . '/view');
    }
}
