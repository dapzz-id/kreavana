<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\{
    ChatController,
    MessageController,
    GroupController,
    UserController,
    DashboardController,
    ProfileController,
    NotificationController,
    CallController,
    AdminController,
    OpportunityController,
};
use App\Http\Controllers\Auth\UserAuthController;
use App\Http\Controllers\Auth\CreatorAuthController;
use App\Http\Controllers\Auth\AdminAuthController;

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

// Backward Compatibility / Legacy Auth Routes (Deprecated)
Route::prefix('auth')->controller(UserAuthController::class)->group(function() {
    Route::post('login', 'login');
    Route::post('register', 'register');
    Route::post('refresh', 'refresh');
});

// New Role-Based Auth Routes (Public)
Route::prefix('auth/user')->controller(UserAuthController::class)->group(function() {
    Route::post('login', 'login');
    Route::post('register', 'register');
    Route::post('refresh', 'refresh');
});

Route::prefix('auth/creator')->controller(CreatorAuthController::class)->group(function() {
    Route::post('login', 'login');
    Route::post('refresh', 'refresh');
});

Route::prefix('auth/admin')->controller(AdminAuthController::class)->group(function() {
    Route::post('login', 'login');
    Route::post('refresh', 'refresh');
});

Route::group(['middleware' => 'auth:api'], function() {
    // Backward Compatibility / Legacy Auth Routes (Authenticated)
    Route::prefix('auth')->controller(UserAuthController::class)->group(function() {
        Route::post('logout', 'logout');
        Route::get('me', 'me');
    });

    // New Role-Based Auth Routes (Authenticated)
    Route::prefix('auth/user')->controller(UserAuthController::class)->group(function() {
        Route::post('logout', 'logout');
        Route::get('me', 'me');
    });

    Route::prefix('auth/creator')->controller(CreatorAuthController::class)->group(function() {
        Route::post('logout', 'logout');
    });

    Route::prefix('auth/admin')->controller(AdminAuthController::class)->group(function() {
        Route::post('logout', 'logout');
    });

    // Dashboard Routes
    Route::prefix('dashboard')->middleware('permission:view_dashboard')->controller(DashboardController::class)->group(function() {
        Route::get('stats', 'stats');
        Route::get('opportunities', 'opportunities');
    });

    // Opportunity Routes (Peluang Lokasi & Proyek)
    Route::prefix('opportunities')->controller(OpportunityController::class)->group(function() {
        Route::get('/', 'index')->middleware('permission:view_opportunities');
        Route::get('map', 'mapLocations')->middleware('permission:view_opportunities');
        Route::post('report', 'submitReport')->middleware('permission:submit_report');
        Route::post('/', 'store')->middleware('permission:create_opportunity');
        Route::get('{id}', 'show')->middleware('permission:view_opportunities');
    });

    // Profile Routes
    Route::prefix('profile')->controller(ProfileController::class)->group(function() {
        Route::get('/', 'getProfile')->middleware('permission:manage_own_profile');
        Route::put('/', 'updateProfile')->middleware('permission:manage_own_profile');
        Route::post('apply-creator', 'applyCreator')->middleware('role:user');
    });

    // Notifications Routes
    Route::prefix('notifications')->controller(NotificationController::class)->group(function() {
        Route::get('/', 'index');
        Route::put('read', 'markAsRead');
    });

    // Call Signaling Route
    Route::prefix('call')->controller(CallController::class)->group(function() {
        Route::post('signal', 'signal');
    });

    // Chat Routes
    Route::prefix('users')->middleware('permission:use_chat')->group(function() {
        Route::get('search', [UserController::class, 'search']);
    });

    Route::prefix('chats')->middleware('permission:use_chat')->controller(ChatController::class)->group(function() {
        Route::get('/', 'index');
        Route::post('personal', 'startPersonalChat');
        
        Route::prefix('{chat}')->controller(MessageController::class)->group(function() {
            Route::get('messages', 'index');
            Route::post('messages', 'store');
        });

        Route::post('{chat}/read', 'markAsRead');
    });

    // Group & Invitations
    Route::prefix('invitations')->middleware('permission:use_chat')->controller(GroupController::class)->group(function() {
        Route::get('/', 'getInvitations');
        Route::post('{chat}/respond', 'respondInvitation');
    });

    Route::prefix('groups')->middleware('permission:use_chat')->controller(GroupController::class)->group(function() {
        Route::post('/', 'store');
        Route::prefix('{chat}')->group(function () {
            Route::get('members', 'members');
            Route::post('members', 'addMember');
            Route::delete('members/{userId}', 'kickMember');
            Route::put('members/{userId}/admin', 'makeAdmin');
            Route::post('leave', 'leaveGroup');
            Route::put('settings', 'updateSettings');
            Route::put('details', 'updateGroupDetails');
        });
    });

    // Admin Routes
    Route::prefix('admin')->middleware('role:admin')->group(function() {
        Route::prefix('applications')->controller(AdminController::class)->group(function() {
            Route::get('/', 'getApplications');
            Route::post('{id}/approve', 'approveApplication');
            Route::post('{id}/reject', 'rejectApplication');
        });
    });
});
