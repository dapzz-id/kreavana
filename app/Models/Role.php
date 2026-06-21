<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Attributes\Fillable;

#[Fillable(['name', 'slug'])]
class Role extends Model
{
    use HasFactory;

    public function users()
    {
        return $this->hasMany(User::class);
    }
}
