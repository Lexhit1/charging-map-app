<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Comment extends Model
{
    use HasFactory;

    protected $fillable = ['point_id', 'comment'];

    public function point()
    {
        return $this->belongsTo(Point::class);
    }
}