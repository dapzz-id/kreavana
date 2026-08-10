<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class MediaDownloadLog extends Model
{
    use HasUuids;

    protected $fillable = [
        'buyer_id',
        'purchased_asset_id',
        'source_file_id',
        'ip_address',
        'user_agent',
        'download_type',
    ];
}
