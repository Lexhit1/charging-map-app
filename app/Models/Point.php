<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Point extends Model
{
    protected $fillable = [
        'user_id', 'name', 'description', 'type', 'address', 'photo_url'
    ];

    protected $casts = [
        'location' => 'string',
    ];

    public function user() {
        return $this->belongsTo(User::class);
    }

    public function comments() {
        return $this->hasMany(Comment::class);
    }

 
    public function getLocationAttribute($value)

    {
     if (!$value) return null;
     // Преобразуем geometry в текст (WKT) — PostGIS функция ST_AsText
     $result = \DB::select("SELECT ST_AsText('{$value}') AS wkt");
     return $result[0]->wkt ?? null;
    }

}   
    