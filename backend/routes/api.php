<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\{
    ChatController, MessageController, GroupController, UserController,
    DashboardController, ProfileController, NotificationController,
    CallController, AdminController, OpportunityController, WalletController,
    RoleController, FollowController, MarketplaceController,
    PaymentMethodController, UserAddressController, AvatarController,
    PortfolioController, SubscriptionController,
    StorageController, DisputeController, OpportunityReviewController,
    AiController
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
Route::prefix('auth')->withoutMiddleware(\App\Http\Middleware\ValidateJti::class)->group(function () {
    Route::post('register', [AuthController::class, 'register'])->middleware('throttle:auth-register');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:auth-login');
    Route::post('refresh', [AuthController::class, 'refresh'])->middleware('throttle:auth-refresh');
    Route::post('user/login', [AuthController::class, 'userLogin'])->middleware('throttle:auth-login');
    Route::post('creator/login', [AuthController::class, 'creatorLogin'])->middleware('throttle:auth-login');
    Route::post('admin/login', [AuthController::class, 'adminLogin'])->middleware('throttle:auth-login');
    Route::post('social', [AuthController::class, 'socialLogin'])->middleware('throttle:auth-login');
});

// Auth & Protected Routes
Route::middleware('auth:api')->group(function () {

    // Auth
    Route::prefix('auth')->group(function () {
        Route::post('logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);
        Route::post('user/change-password', [AuthController::class, 'changePassword']);
        Route::post('user/set-initial-password', [AuthController::class, 'setInitialPassword']);
    });

    // Payment Methods
    Route::prefix('payment-methods')->middleware('permission:manage_own_profile')->group(function () {
        Route::get('/', [PaymentMethodController::class, 'index']);
        Route::post('/', [PaymentMethodController::class, 'store']);
        Route::put('{id}', [PaymentMethodController::class, 'update']);
        Route::put('{id}/default', [PaymentMethodController::class, 'setDefault']);
        Route::delete('{id}', [PaymentMethodController::class, 'destroy']);
    });

    // User Addresses
    Route::prefix('user-addresses')->middleware('permission:manage_own_profile')->group(function () {
        Route::get('/', [UserAddressController::class, 'index']);
        Route::post('/', [UserAddressController::class, 'store']);
        Route::put('{id}', [UserAddressController::class, 'update']);
        Route::put('{id}/default', [UserAddressController::class, 'setDefault']);
        Route::delete('{id}', [UserAddressController::class, 'destroy']);
    });

    // Portfolio
    Route::prefix('portfolio')->group(function () {
        Route::get('/', [PortfolioController::class, 'index']);
        Route::post('/', [PortfolioController::class, 'store']);
        Route::put('reorder', [PortfolioController::class, 'reorder']);
        Route::put('{id}', [PortfolioController::class, 'update']);
        Route::delete('{id}', [PortfolioController::class, 'destroy']);
    });

    // Profile & Settings
    Route::prefix('profile')->group(function () {
        Route::get('/', [ProfileController::class, 'getProfile'])->middleware('permission:view_own_profile');
        Route::put('/', [ProfileController::class, 'updateProfile'])->middleware('permission:manage_own_profile');
        Route::get('application', [ProfileController::class, 'application'])->middleware('permission:manage_own_profile');
        Route::get('identity', [ProfileController::class, 'identity'])->middleware('permission:view_own_profile');
        Route::get('permissions', [ProfileController::class, 'permissions'])->middleware('permission:view_own_profile');
        Route::get('history', [ProfileController::class, 'history'])->middleware('permission:manage_own_profile');
        Route::post('apply-creator', [ProfileController::class, 'applyCreator'])->middleware('role:user');
    });

    Route::put('user/public-key', [ProfileController::class, 'updatePublicKey'])->middleware('auth:api');

    // Follows
    Route::prefix('follow')->group(function () {
        Route::post('{userId}', [FollowController::class, 'follow']);
        Route::delete('{userId}', [FollowController::class, 'unfollow']);
    });
    Route::get('users/{userId}/followers', [FollowController::class, 'followers']);
    Route::get('users/{userId}/following', [FollowController::class, 'following']);

    // Dashboard
    Route::prefix('dashboard')->group(function () {
        Route::get('stats', [DashboardController::class, 'stats'])->middleware('permission:view_dashboard');
        Route::get('opportunities', [DashboardController::class, 'opportunities']);
    });
    Route::get('client-dashboard/overview', [DashboardController::class, 'overview'])->middleware('permission:view_dashboard');

    // Wallet
    Route::prefix('wallet')->middleware('permission:manage_own_profile')->group(function () {
        Route::get('info', [WalletController::class, 'info']);
        Route::get('has-pin', [WalletController::class, 'hasPin']);
        Route::post('set-pin', [WalletController::class, 'setPin']);
        Route::post('verify-pin', [WalletController::class, 'verifyPin']);
        Route::post('topup', [WalletController::class, 'topup']);
        Route::post('topup/simulate', [WalletController::class, 'simulatePay']);
        Route::post('transfer', [WalletController::class, 'transfer']);
        Route::post('withdraw', [WalletController::class, 'withdraw']);
    });

    // Opportunities
    Route::prefix('opportunities')->group(function () {
        Route::get('/', [OpportunityController::class, 'index'])->middleware('permission:view_opportunities');
        Route::post('/', [OpportunityController::class, 'store'])->middleware('permission:create_opportunity');
        Route::get('map', [OpportunityController::class, 'mapLocations'])->middleware('permission:view_opportunities');
        Route::post('report', [OpportunityController::class, 'submitReport'])->middleware('permission:submit_report');
        Route::get('{id}', [OpportunityController::class, 'show'])->middleware('permission:view_opportunities');
        Route::get('{id}/poster', [OpportunityController::class, 'getPoster'])->middleware('permission:view_opportunities');
    });

    // Notifications
    Route::prefix('notifications')->group(function () {
        Route::get('/', [NotificationController::class, 'index']);
        Route::get('unread-count', [NotificationController::class, 'unreadCount']);
        Route::put('read', [NotificationController::class, 'markAsRead']);
        Route::delete('{id}', [NotificationController::class, 'destroy']);
        Route::delete('/', [NotificationController::class, 'destroyAll']);
    });

    // Call Signaling
    Route::post('call/signal', [CallController::class, 'signal']);

    // Unread counts (combined - optimized single query)
    Route::get('unread-count', function (Request $request) {
        $userId = $request->user()->id;
        $notifCount = \App\Models\Notification::where('user_id', $userId)
            ->where('is_read', false)
            ->count();
        $chatCount = \App\Models\ChatParticipant::where('chat_participants.user_id', $userId)
            ->where('chat_participants.status', 'joined')
            ->join('messages', function ($join) use ($userId) {
                $join->on('messages.chat_id', '=', 'chat_participants.chat_id')
                     ->where('messages.user_id', '!=', $userId)
                     ->whereRaw('messages.created_at > COALESCE(chat_participants.last_read_at, chat_participants.created_at, "2000-01-01 00:00:00")');
            })
            ->count();
        return response()->json([
            'status' => true,
            'data' => [
                'unread_notifications' => $notifCount,
                'unread_messages' => $chatCount,
            ],
        ]);
    });

    // Chat Users Search
    Route::prefix('users')->middleware('permission:use_chat')->group(function () {
        Route::get('search', [UserController::class, 'search']);
        Route::get('contacts', [UserController::class, 'contacts']);
        Route::post('fcm-token', [UserController::class, 'updateFcmToken']);
    });
    Route::post('user/devices', [UserController::class, 'registerDevice'])->middleware('permission:use_chat');

    // Chats
    Route::prefix('chats')->middleware('permission:use_chat')->group(function () {
        Route::get('/', [ChatController::class, 'index']);
        Route::get('unread-count', [ChatController::class, 'unreadCount']);
        Route::post('personal', [ChatController::class, 'startPersonalChat']);
        Route::post('read-all', [ChatController::class, 'markAllAsRead']);

        Route::prefix('{chat}')->group(function () {
            Route::post('read', [ChatController::class, 'markAsRead']);
            Route::get('devices', [ChatController::class, 'devices']);
            Route::get('messages', [MessageController::class, 'index']);
            Route::post('messages', [MessageController::class, 'store']);
            Route::post('messages/{message}/delete', [MessageController::class, 'destroy']);
        });
    });

    Route::post('presence/ping', [ChatController::class, 'presencePing'])->middleware('permission:use_chat');

    // Invitations
    Route::prefix('invitations')->middleware('permission:use_chat')->group(function () {
        Route::get('/', [GroupController::class, 'getInvitations']);
        Route::post('{chat}/respond', [GroupController::class, 'respondInvitation']);
    });

    // Groups
    Route::prefix('groups')->middleware('permission:use_chat')->group(function () {
        Route::post('/', [GroupController::class, 'store']);

        Route::prefix('{chat}')->group(function () {
            Route::get('members', [GroupController::class, 'members']);
            Route::post('members', [GroupController::class, 'addMember']);
            Route::delete('members/{userId}', [GroupController::class, 'kickMember']);
            Route::put('members/{userId}/admin', [GroupController::class, 'makeAdmin']);
            Route::post('leave', [GroupController::class, 'leaveGroup']);
            Route::put('settings', [GroupController::class, 'updateSettings']);
            Route::put('details', [GroupController::class, 'updateGroupDetails']);
        });
    });

    // Admin
    Route::prefix('admin')->middleware('role:admin')->group(function () {
        Route::get('applications', [AdminController::class, 'getApplications']);
        Route::post('applications/{id}/approve', [AdminController::class, 'approveApplication']);
        Route::post('applications/{id}/reject', [AdminController::class, 'rejectApplication']);
        Route::get('system-logs', [AdminController::class, 'getSystemLogs']);
        Route::get('assigned-disputes', [DisputeController::class, 'assignedDisputes']);
    });

    // Marketplace (write operations)
    Route::prefix('marketplace')->group(function () {
        Route::post('/', [MarketplaceController::class, 'store']);
        Route::put('{id}', [MarketplaceController::class, 'update']);
        Route::delete('{id}', [MarketplaceController::class, 'destroy']);
        Route::post('{id}/review', [MarketplaceController::class, 'review']);
        Route::get('{id}/purchases', [MarketplaceController::class, 'purchases']);
        Route::post('{id}/purchase', [MarketplaceController::class, 'purchase']);
    });

    // Subscription (authenticated)
    Route::prefix('subscription')->group(function () {
        Route::post('purchase', [SubscriptionController::class, 'purchase']);
        Route::get('current', [SubscriptionController::class, 'getCurrent']);
    });

    // Storage Management
    Route::prefix('storage')->group(function () {
        Route::get('history', [StorageController::class, 'history']);
        Route::delete('{id}', [StorageController::class, 'destroy']);
        Route::post('purchased/{id}/retry', [StorageController::class, 'retryPurchasedClone']);
        Route::get('purchased/{id}/download', [StorageController::class, 'downloadPurchasedAsset']);
    });

    // AI Service (Protected, Requires Pro/Super subscription tier)
    Route::prefix('ai')->group(function () {
        Route::post('summarize-report', [AiController::class, 'summarizeReport']);
        Route::post('recommendations', [AiController::class, 'getRecommendations']);
        Route::post('message-assistant', [AiController::class, 'messageAssistant']);
    });
});

// Storage Management (Public Read for Status)
Route::get('storage/file/{id}/status', [StorageController::class, 'status']);

// Marketplace (public read)
Route::prefix('marketplace')->group(function () {
    Route::get('/', [MarketplaceController::class, 'index']);
    Route::get('featured', [MarketplaceController::class, 'featured']);
    Route::get('categories', [MarketplaceController::class, 'categories']);
    Route::get('{id}', [MarketplaceController::class, 'show']);
});

// Subscription plans (public — prices are defined server-side, never trust the client)
Route::prefix('subscription')->group(function () {
    Route::get('plans', [SubscriptionController::class, 'plans']);
});
