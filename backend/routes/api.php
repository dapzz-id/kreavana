<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\{
    ChatController, MessageController, GroupController, UserController,
    DashboardController, ProfileController, NotificationController,
    CallController, AdminController, OpportunityController, WalletController,
    RoleController, FollowController
};

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

// Roles endpoints
Route::get('roles/creator/sub-roles', [RoleController::class, 'getCreatorSubRoles']);

// Auth (Public)
Route::post('auth/register', [AuthController::class, 'register'])
    ->middleware('throttle:auth-register')
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class);
Route::post('auth/login', [AuthController::class, 'login'])
    ->middleware('throttle:auth-login')
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class);
Route::post('auth/refresh', [AuthController::class, 'refresh'])
    ->middleware('throttle:auth-refresh')
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class);
Route::post('auth/user/login', [AuthController::class, 'userLogin'])
    ->middleware('throttle:auth-login')
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class);
Route::post('auth/creator/login', [AuthController::class, 'creatorLogin'])
    ->middleware('throttle:auth-login')
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class);
Route::post('auth/admin/login', [AuthController::class, 'adminLogin'])
    ->middleware('throttle:auth-login')
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class);

// Auth & Protected Routes
Route::middleware('auth:api')->group(function () {
    // Auth
    Route::post('auth/logout', [AuthController::class, 'logout']);
    Route::get('auth/me', [AuthController::class, 'me']);

    // Profile
    Route::get('profile', [ProfileController::class, 'getProfile'])->middleware('permission:manage_own_profile');
    Route::get('profile/identity', [ProfileController::class, 'identity'])->middleware('permission:manage_own_profile');
    Route::get('profile/application', [ProfileController::class, 'application'])->middleware('permission:manage_own_profile');
    Route::get('profile/permissions', [ProfileController::class, 'permissions'])->middleware('permission:manage_own_profile');
    Route::put('profile', [ProfileController::class, 'updateProfile'])->middleware('permission:manage_own_profile');
    Route::get('profile/history', [ProfileController::class, 'history'])->middleware('permission:manage_own_profile');
    Route::post('profile/apply-creator', [ProfileController::class, 'applyCreator'])->middleware('role:user');

    // Follows
    Route::post('follow/{userId}', [FollowController::class, 'follow']);
    Route::delete('follow/{userId}', [FollowController::class, 'unfollow']);
    Route::get('users/{userId}/followers', [FollowController::class, 'followers']);
    Route::get('users/{userId}/following', [FollowController::class, 'following']);

    // Dashboard
    Route::get('dashboard/stats', [DashboardController::class, 'stats'])->middleware('permission:view_dashboard');
    Route::get('dashboard/opportunities', [DashboardController::class, 'opportunities'])->middleware('permission:view_dashboard');

    // Wallet
    Route::get('wallet/info', [WalletController::class, 'info'])->middleware('permission:manage_own_profile');
    Route::post('wallet/topup', [WalletController::class, 'topup'])->middleware('permission:manage_own_profile');
    Route::post('wallet/topup/simulate', [WalletController::class, 'simulatePay'])->middleware('permission:manage_own_profile');
    Route::post('wallet/transfer', [WalletController::class, 'transfer'])->middleware('permission:manage_own_profile');
    Route::post('wallet/withdraw', [WalletController::class, 'withdraw'])->middleware('permission:manage_own_profile');

    // Opportunities
    Route::get('opportunities', [OpportunityController::class, 'index'])->middleware('permission:view_opportunities');
    Route::post('opportunities', [OpportunityController::class, 'store'])->middleware('permission:create_opportunity');
    Route::get('opportunities/map', [OpportunityController::class, 'mapLocations'])->middleware('permission:view_opportunities');
    Route::post('opportunities/report', [OpportunityController::class, 'submitReport'])->middleware('permission:submit_report');
    Route::get('opportunities/{id}', [OpportunityController::class, 'show'])->middleware('permission:view_opportunities');
    Route::get('opportunities/{id}/poster', [OpportunityController::class, 'getPoster'])->middleware('permission:view_opportunities');

    // Notifications
    Route::get('notifications', [NotificationController::class, 'index']);
    Route::put('notifications/read', [NotificationController::class, 'markAsRead']);

    // Call Signaling
    Route::post('call/signal', [CallController::class, 'signal']);

    // Chat Users Search
    Route::get('users/search', [UserController::class, 'search'])->middleware('permission:use_chat');

    // Chats
    Route::get('chats', [ChatController::class, 'index'])->middleware('permission:use_chat');
    Route::post('chats/personal', [ChatController::class, 'startPersonalChat'])->middleware('permission:use_chat');
    Route::post('chats/{chat}/read', [ChatController::class, 'markAsRead'])->middleware('permission:use_chat');

    // Messages
    Route::get('chats/{chat}/messages', [MessageController::class, 'index'])->middleware('permission:use_chat');
    Route::post('chats/{chat}/messages', [MessageController::class, 'store'])->middleware('permission:use_chat');

    // Invitations
    Route::get('invitations', [GroupController::class, 'getInvitations'])->middleware('permission:use_chat');
    Route::post('invitations/{chat}/respond', [GroupController::class, 'respondInvitation'])->middleware('permission:use_chat');

    // Groups
    Route::post('groups', [GroupController::class, 'store'])->middleware('permission:use_chat');
    Route::get('groups/{chat}/members', [GroupController::class, 'members'])->middleware('permission:use_chat');
    Route::post('groups/{chat}/members', [GroupController::class, 'addMember'])->middleware('permission:use_chat');
    Route::delete('groups/{chat}/members/{userId}', [GroupController::class, 'kickMember'])->middleware('permission:use_chat');
    Route::put('groups/{chat}/members/{userId}/admin', [GroupController::class, 'makeAdmin'])->middleware('permission:use_chat');
    Route::post('groups/{chat}/leave', [GroupController::class, 'leaveGroup'])->middleware('permission:use_chat');
    Route::put('groups/{chat}/settings', [GroupController::class, 'updateSettings'])->middleware('permission:use_chat');
    Route::put('groups/{chat}/details', [GroupController::class, 'updateGroupDetails'])->middleware('permission:use_chat');

    // Admin
    Route::get('admin/applications', [AdminController::class, 'getApplications'])->middleware('role:admin');
    Route::post('admin/applications/{id}/approve', [AdminController::class, 'approveApplication'])->middleware('role:admin');
    Route::post('admin/applications/{id}/reject', [AdminController::class, 'rejectApplication'])->middleware('role:admin');
});
