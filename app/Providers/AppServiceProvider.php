<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\Gate;

// Repository Contracts
use App\Repositories\Contracts\RoleRepositoryInterface;
use App\Repositories\Contracts\UserRepositoryInterface;
use App\Repositories\Contracts\PhotoRepositoryInterface;
use App\Repositories\Contracts\PhotographerRequestRepositoryInterface;
use App\Repositories\Contracts\PurchaseRepositoryInterface;
use App\Repositories\Contracts\LedgerRepositoryInterface;
use App\Repositories\Contracts\SocialRepositoryInterface;

// Eloquent Implementations
use App\Repositories\Eloquent\EloquentRoleRepository;
use App\Repositories\Eloquent\EloquentUserRepository;
use App\Repositories\Eloquent\EloquentPhotoRepository;
use App\Repositories\Eloquent\EloquentPhotographerRequestRepository;
use App\Repositories\Eloquent\EloquentPurchaseRepository;
use App\Repositories\Eloquent\EloquentLedgerRepository;
use App\Repositories\Eloquent\EloquentSocialRepository;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     * Bind each repository interface to its concrete Eloquent implementation.
     * Swapping DB drivers in future only requires changing these bindings.
     */
    public function register(): void
    {
        $this->app->bind(RoleRepositoryInterface::class, EloquentRoleRepository::class);
        $this->app->bind(UserRepositoryInterface::class, EloquentUserRepository::class);
        $this->app->bind(PhotoRepositoryInterface::class, EloquentPhotoRepository::class);
        $this->app->bind(PhotographerRequestRepositoryInterface::class, EloquentPhotographerRequestRepository::class);
        $this->app->bind(PurchaseRepositoryInterface::class, EloquentPurchaseRepository::class);
        $this->app->bind(LedgerRepositoryInterface::class, EloquentLedgerRepository::class);
        $this->app->bind(SocialRepositoryInterface::class, EloquentSocialRepository::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Gate::define('superadmin', function (\App\Models\User $user) {
            return $user->isSuperadmin();
        });

        Gate::define('photographer', function (\App\Models\User $user) {
            return $user->isPhotographer();
        });

        Gate::define('regular-user', function (\App\Models\User $user) {
            return $user->isUser();
        });
    }
}
