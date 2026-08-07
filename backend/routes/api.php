<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\{
    ChatController, MessageController, GroupController, UserController,
    DashboardController, ProfileController, NotificationController,
    CallController, AdminController, OpportunityController, WalletController,
    RoleController, FollowController, MarketplaceController,
    PaymentMethodController, UserAddressController, AvatarController
};

// Public: serve avatar images with CORS headers (for Flutter Web)
Route::get('avatars/{file}', [AvatarController::class, 'show'])
    ->where('file', '.*')
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class)
    ->withoutMiddleware(\App\Http\Middleware\TouchLastOnline::class);

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

// Social Login (Google, Apple)
Route::post('auth/social', [AuthController::class, 'socialLogin'])
    ->middleware('throttle:auth-login')
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class);

// Auth & Protected Routes
Route::middleware('auth:api')->group(function () {
    // Auth
    Route::post('auth/logout', [AuthController::class, 'logout']);
    Route::get('auth/me', [AuthController::class, 'me']);
    Route::post('auth/user/change-password', [AuthController::class, 'changePassword']);

    // Payment Methods
    Route::get('payment-methods', [PaymentMethodController::class, 'index'])->middleware('permission:manage_own_profile');
    Route::post('payment-methods', [PaymentMethodController::class, 'store'])->middleware('permission:manage_own_profile');
    Route::put('payment-methods/{id}', [PaymentMethodController::class, 'update'])->middleware('permission:manage_own_profile');
    Route::put('payment-methods/{id}/default', [PaymentMethodController::class, 'setDefault'])->middleware('permission:manage_own_profile');
    Route::delete('payment-methods/{id}', [PaymentMethodController::class, 'destroy'])->middleware('permission:manage_own_profile');

    // User Addresses
    Route::get('user-addresses', [UserAddressController::class, 'index'])->middleware('permission:manage_own_profile');
    Route::post('user-addresses', [UserAddressController::class, 'store'])->middleware('permission:manage_own_profile');
    Route::put('user-addresses/{id}', [UserAddressController::class, 'update'])->middleware('permission:manage_own_profile');
    Route::put('user-addresses/{id}/default', [UserAddressController::class, 'setDefault'])->middleware('permission:manage_own_profile');
    Route::delete('user-addresses/{id}', [UserAddressController::class, 'destroy'])->middleware('permission:manage_own_profile');

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
    Route::get('dashboard/opportunities', [DashboardController::class, 'opportunities']);
    Route::get('client-dashboard/overview', [DashboardController::class, 'overview'])->middleware('permission:view_dashboard');

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
    Route::get('notifications/unread-count', [NotificationController::class, 'unreadCount']);
    Route::put('notifications/read', [NotificationController::class, 'markAsRead']);

    // Call Signaling
    Route::post('call/signal', [CallController::class, 'signal']);

    // Unread counts (combined)
    Route::get('unread-count', function (Request $request) {
        $userId = $request->user()->id;
        $notifCount = \App\Models\Notification::where('user_id', $userId)
            ->where('is_read', false)
            ->count();
        $chatParticipants = \App\Models\ChatParticipant::where('user_id', $userId)
            ->where('status', 'joined')
            ->with('chat')
            ->get();
        $chatCount = 0;
        foreach ($chatParticipants as $p) {
            $chatCount += $p->chat->messages()
                ->where('user_id', '!=', $userId)
                ->where('created_at', '>', $p->last_read_at ?? '2000-01-01 00:00:00')
                ->count();
        }
        return response()->json([
            'status' => true,
            'data' => [
                'unread_notifications' => $notifCount,
                'unread_messages' => $chatCount,
            ],
        ]);
    });

    // Chat Users Search
    Route::get('users/search', [UserController::class, 'search'])->middleware('permission:use_chat');
    Route::get('users/contacts', [UserController::class, 'contacts'])->middleware('permission:use_chat');

    // Chats
    Route::get('chats', [ChatController::class, 'index'])->middleware('permission:use_chat');
    Route::get('chats/unread-count', [ChatController::class, 'unreadCount'])->middleware('permission:use_chat');
    Route::post('chats/personal', [ChatController::class, 'startPersonalChat'])->middleware('permission:use_chat');
    Route::post('chats/{chat}/read', [ChatController::class, 'markAsRead'])->middleware('permission:use_chat');
    Route::post('presence/ping', [ChatController::class, 'presencePing'])->middleware('permission:use_chat');

    // Messages
    Route::get('chats/{chat}/messages', [MessageController::class, 'index'])->middleware('permission:use_chat');
    Route::post('chats/{chat}/messages', [MessageController::class, 'store'])->middleware('permission:use_chat');
    Route::post('chats/{chat}/messages/{message}/delete', [MessageController::class, 'destroy'])->middleware('permission:use_chat');

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

    // Marketplace (write operations)
    Route::post('marketplace', [MarketplaceController::class, 'store']);
    Route::put('marketplace/{id}', [MarketplaceController::class, 'update']);
    Route::delete('marketplace/{id}', [MarketplaceController::class, 'destroy']);
    Route::post('marketplace/{id}/review', [MarketplaceController::class, 'review']);
});

// Marketplace (public read)
Route::get('marketplace', [MarketplaceController::class, 'index']);
Route::get('marketplace/featured', [MarketplaceController::class, 'featured']);
Route::get('marketplace/categories', [MarketplaceController::class, 'categories']);
Route::get('marketplace/{id}', [MarketplaceController::class, 'show']);
