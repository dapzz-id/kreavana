<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DashboardStat extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'pihak_slug',
        'role_type',
        'stat_label',
        'stat_value',
        'stat_icon',
        'display_order'
    ];
}
