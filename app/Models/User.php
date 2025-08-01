<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, Notifiable;

    protected $fillable = [
        'username', 'password', 'points_created',
    ];

    protected $hidden = [
        'password',
    ];

    public function points() {
        return $this->hasMany(Point::class);
    }
}	