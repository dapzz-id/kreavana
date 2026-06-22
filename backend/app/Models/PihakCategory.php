<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PihakCategory extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'slug',
        'name',
        'description',
        'icon',
        'color'
    ];
}
