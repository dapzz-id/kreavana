<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\{
    ChatController,
    MessageController,
    GroupController,
    UserController,
    AuthController,
    DashboardController,
    ProfileController,
    NotificationController,
    CallController,
    AdminController,
    OpportunityController,
};

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

// Auth Routes
Route::prefix('auth')->controller(AuthController::class)->group(function() {
    Route::post('login', 'login');
    Route::post('register', 'register');
    Route::post('refresh', 'refresh');
});

Route::group(['middleware' => 'auth:api'], function() {
    Route::prefix('auth')->controller(AuthController::class)->group(function() {
        Route::post('logout', 'logout');
        Route::get('me', 'me');
    });

    // Dashboard Routes
    Route::prefix('dashboard')->controller(DashboardController::class)->group(function() {
        Route::get('stats', 'stats');
        Route::get('opportunities', 'opportunities');
    });

    // Opportunity Routes (Peluang Lokasi & Proyek)
    Route::prefix('opportunities')->controller(OpportunityController::class)->group(function() {
        Route::get('/', 'index');
        Route::get('map', 'mapLocations');
        Route::post('report', 'submitReport');
        Route::post('/', 'store');
        Route::get('{id}', 'show');
    });

    // Profile Routes
    Route::prefix('profile')->controller(ProfileController::class)->group(function() {
        Route::get('/', 'getProfile');
        Route::put('/', 'updateProfile');
        Route::post('apply-creator', 'applyCreator');
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
    Route::prefix('users')->group(function() {
        Route::get('search', [UserController::class, 'search']);
    });

    Route::prefix('chats')->controller(ChatController::class)->group(function() {
        Route::get('/', 'index');
        Route::post('personal', 'startPersonalChat');
        
        Route::prefix('{chat}')->controller(MessageController::class)->group(function() {
            Route::get('messages', 'index');
            Route::post('messages', 'store');
        });

        Route::post('{chat}/read', 'markAsRead');
    });

    // Group & Invitations
    Route::prefix('invitations')->controller(GroupController::class)->group(function() {
        Route::get('/', 'getInvitations');
        Route::post('{chat}/respond', 'respondInvitation');
    });

    Route::prefix('groups')->controller(GroupController::class)->group(function() {
        Route::post('/', 'store');
        Route::prefix('{chat}')->group(function () {
            Route::get('members', 'members');
            Route::post('members', 'addMember');
            Route::delete('members/{userId}', 'kickMember');
            Route::put('members/{userId}/admin', 'makeAdmin');
            Route::post('leave', 'leaveGroup');
            Route::put('settings', 'updateSettings');
        });
    });

    // Admin Routes
    Route::prefix('admin')->group(function() {
        Route::prefix('applications')->controller(AdminController::class)->group(function() {
            Route::get('/', 'getApplications');
            Route::post('{id}/approve', 'approveApplication');
            Route::post('{id}/reject', 'rejectApplication');
        });
    });
});
