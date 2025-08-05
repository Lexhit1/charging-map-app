<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * Атрибуты, доступные для массового заполнения.
     *
     * @var array
     */
    protected $fillable = [
        'username',
        'password',
        'points_created',
    ];

    /**
     * Атрибуты, скрытые при приведении к массиву или JSON.
     *
     * @var array
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Атрибуты, которые следует привести к нативным типам.
     *
     * @var array
     */
    protected $casts = [
        'points_created' => 'integer',
        'email_verified_at' => 'datetime',
    ];

    /**
     * Мутатор для автоматического хеширования пароля.
     *
     * @param  string  $value
     * @return void
     */
    public function setPasswordAttribute(string $value)
    {
        // Если пароль не пуст, хешируем его перед сохранением
        if ($value != '') {
        $this->attributes['password'] = bcrypt($value);
    }
}
}