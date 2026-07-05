<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;

class DashboardStat extends Model
{
    use HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'sub_role_slug',
        'role_type',
        'stat_label',
        'stat_value',
        'stat_icon',
        'display_order'
    ];
}
