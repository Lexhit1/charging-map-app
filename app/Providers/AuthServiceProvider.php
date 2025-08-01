<?php  // Ничего перед этим!

namespace App\Providers;

use Illuminate\Foundation\Support\Providers\AuthServiceProvider as BaseAuthServiceProvider;
use Illuminate\Support\ServiceProvider;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Notifications\Messages\MailMessage;

class AuthServiceProvider extends \Illuminate\Foundation\Support\Providers\AuthServiceProvider
{
    protected $policies = [
        // 'App\Models\Model' => 'App\Policies\ModelPolicy',
    ];

    public function boot(): void
    {
        $this->registerPolicies();

        // Кастомные настройки, если нужно (например, для Sanctum)
        ResetPassword::createUrlUsing(function ($user, string $token) {
            return 'http://your-frontend-url/reset-password?token=' . $token;
        });
    }
}