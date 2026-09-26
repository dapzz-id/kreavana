<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\{
    Auth\AuthController, ChatController, MessageController, GroupController, UserController,
    DashboardController, ProfileController, NotificationController,
    CallController, AdminController, OpportunityController, WalletController,
    RoleController, FollowController, MarketplaceController,
    PaymentMethodController, PaymentProviderController, UserAddressController, AvatarController,
    PortfolioController, SubscriptionController,
    StorageController, DisputeController, OpportunityReviewController,
    AiController, JobContractController, JobContractTransitionController,
    MarketingController, AdminSystemSettingController, CollaborationController
};

// Public: serve avatar images with CORS headers (for Flutter Web)
Route::get('avatars/{file}', [AvatarController::class, 'show'])
    ->where('file', '.*')
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class)
    ->withoutMiddleware(\App\Http\Middleware\TouchLastOnline::class);

// Public: serve portfolio images with CORS headers (for Flutter Web)
Route::get('portfolio-assets/{file}', [PortfolioController::class, 'showAsset'])
    ->where('file', '.*')
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class)
    ->withoutMiddleware(\App\Http\Middleware\TouchLastOnline::class);

// Public: serve verification documents (KTP & Selfie) with CORS headers (for Flutter Web)
Route::get('verification-assets/{type}/{file}', [ProfileController::class, 'showVerificationAsset'])
    ->where('file', '.*')
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class)
    ->withoutMiddleware(\App\Http\Middleware\TouchLastOnline::class);

Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

// Public creator profiles & reputation
Route::prefix('creators')->group(function () {
    Route::get('{id}/reviews', [OpportunityReviewController::class, 'listCreatorReviews']);
    Route::get('{id}/reviews/summary', [OpportunityReviewController::class, 'getCreatorReviewSummary']);
});

// Roles endpoints
Route::get('roles/creator/sub-roles', [RoleController::class, 'getCreatorSubRoles']);

// Public System Statuses
Route::get('system/module-statuses', [AdminSystemSettingController::class, 'getPublicModuleStatuses'])
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class);

// Reviews & Reputation (Database driven)
Route::get('reviews', [OpportunityReviewController::class, 'index'])
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class);
Route::post('reviews/{id}/helpful', [OpportunityReviewController::class, 'helpful'])
    ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class);

// Payment Providers — public list of supported banks & e-wallets
Route::prefix('payment-providers')->group(function () {
    Route::get('/', [PaymentProviderController::class, 'index']);
    Route::get('{id}', [PaymentProviderController::class, 'show']);
});

// Auth (Public)
Route::prefix('auth')->withoutMiddleware(\App\Http\Middleware\ValidateJti::class)->group(function () {
    Route::post('register', [AuthController::class, 'register'])->middleware('throttle:auth-register');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:auth-login');
    Route::post('refresh', [AuthController::class, 'refresh'])->middleware('throttle:auth-refresh');
    Route::post('user/login', [AuthController::class, 'userLogin'])->middleware('throttle:auth-login');
    Route::post('creator/login', [AuthController::class, 'creatorLogin'])->middleware('throttle:auth-login');
    Route::post('admin/login', [AuthController::class, 'adminLogin'])->middleware('throttle:auth-login');
    Route::post('social', [AuthController::class, 'socialLogin'])->middleware('throttle:auth-login');
    Route::post('verify-email', [AuthController::class, 'verifyEmail'])->middleware('throttle:auth-verify-email');
    Route::post('resend-verification', [AuthController::class, 'resendVerificationCode'])->middleware('throttle:auth-resend-verification');
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

    // Verification
    Route::prefix('verification')->group(function () {
        Route::get('status', [ProfileController::class, 'getVerificationStatus']);
        Route::post('client', [ProfileController::class, 'applyClientVerification'])->middleware('role:user');
    });

    // Public User Profile
    Route::get('users/{id}/profile', [ProfileController::class, 'getPublicProfile'])
        ->withoutMiddleware(\App\Http\Middleware\ValidateJti::class);

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
    // Wallet
    Route::prefix('wallet')->middleware(['permission:manage_own_profile', 'module:wallet_enabled'])->group(function () {
        Route::get('info', [WalletController::class, 'info']);
        Route::get('has-pin', [WalletController::class, 'hasPin']);
        Route::post('set-pin', [WalletController::class, 'setPin']);
        Route::post('verify-pin', [WalletController::class, 'verifyPin']);
        Route::get('fees', [WalletController::class, 'getFees']);
        Route::post('topup', [WalletController::class, 'topup']);
        Route::post('topup/simulate', [WalletController::class, 'simulatePay']);
        Route::post('transfer', [WalletController::class, 'transfer']);
        Route::post('withdraw', [WalletController::class, 'withdraw']);
    });

    // Opportunities (Write & Applications)
    Route::prefix('opportunities')->group(function () {
        Route::get('my', [OpportunityController::class, 'myOpportunities']);
        Route::post('/', [OpportunityController::class, 'store'])->middleware('permission:create_opportunity');
        Route::post('report', [OpportunityController::class, 'submitReport'])->middleware('permission:submit_report');
        Route::post('{id}/reviews', [OpportunityReviewController::class, 'store']);
        Route::post('{id}/applications', [OpportunityController::class, 'apply']);
        Route::get('{id}/applications', [OpportunityController::class, 'applications']);
        Route::post('applications/{id}/approve', [OpportunityController::class, 'approveApplication']);
        Route::post('applications/{id}/reject', [OpportunityController::class, 'rejectApplication']);
        Route::post('{id}/start-event', [OpportunityController::class, 'startEvent']);
        Route::post('{id}/update-progress', [OpportunityController::class, 'updateProgress']);
        Route::post('{id}/schedule-meeting', [OpportunityController::class, 'scheduleMeeting']);
        Route::post('applications/{id}/submit-documents', [OpportunityController::class, 'submitDocuments']);
    });

    // Marketing (High-Value Deals & Reviews)
    Route::prefix('marketing')->middleware('role:marketing,admin')->group(function () {
        Route::get('transactions', [MarketingController::class, 'index']);
        Route::get('transactions/{id}', [MarketingController::class, 'show']);
        Route::post('transactions/{id}/assign', [MarketingController::class, 'assign']);
        Route::post('transactions/{id}/verify', [MarketingController::class, 'verify']);
        Route::post('transactions/{id}/approve', [MarketingController::class, 'approve']);
        Route::post('transactions/{id}/reject', [MarketingController::class, 'reject']);
        Route::get('opportunities', [MarketingController::class, 'listHighValueOpportunities']);
        Route::post('opportunities/{id}/confirm-payment', [MarketingController::class, 'confirmOpportunityPayment']);
    });

    // Collaborations
    Route::prefix('collaborations')->group(function () {
        Route::get('/', [CollaborationController::class, 'index']);
        Route::post('/', [CollaborationController::class, 'store']);
        Route::get('{id}', [CollaborationController::class, 'show']);
        Route::post('{id}/respond', [CollaborationController::class, 'respond']);
        Route::put('{id}', [CollaborationController::class, 'update']);
        Route::delete('{id}', [CollaborationController::class, 'destroy']);
    });

    // Job Contracts
    Route::prefix('contracts')->group(function () {
        Route::get('/', [JobContractController::class, 'index']);
        Route::post('/', [JobContractController::class, 'store']);
        Route::get('{id}', [JobContractController::class, 'show']);
        Route::post('{contract}/transitions', [JobContractTransitionController::class, 'store']);
    });

    // Notifications
    Route::prefix('notifications')->group(function () {
        Route::get('/', [NotificationController::class, 'index']);
        Route::get('unread-count', [NotificationController::class, 'unreadCount']);
        Route::put('read', [NotificationController::class, 'markAsRead']);
        Route::delete('{id}', [NotificationController::class, 'destroy']);
        Route::delete('/', [NotificationController::class, 'destroyAll']);
    });

    // Call Signaling & TURN credentials
    Route::prefix('call')->group(function () {
        Route::post('signal', [CallController::class, 'signal']);
        Route::post('turn-credentials', [CallController::class, 'getTurnCredentials']);
    });

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
                     ->whereRaw(
                            'messages.created_at > COALESCE(chat_participants.last_read_at, chat_participants.created_at, ?)',
                            ['2000-01-01 00:00:00']
                        );
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
        Route::get('stats/summary', [AdminController::class, 'getDashboardSummary']);
        Route::get('applications', [AdminController::class, 'getApplications']);
        Route::post('applications/{id}/approve', [AdminController::class, 'approveApplication']);
        Route::post('applications/{id}/reject', [AdminController::class, 'rejectApplication']);
        Route::get('system-logs', [AdminController::class, 'getSystemLogs']);
        Route::get('assigned-disputes', [DisputeController::class, 'assignedDisputes']);
        Route::post('disputes/{id}/decision-refund', [DisputeController::class, 'adminDecideRefund']);
        Route::post('disputes/{id}/settle-refund', [DisputeController::class, 'adminSettleRefund']);
        Route::post('disputes/{id}/decision-cancellation', [DisputeController::class, 'adminDecideCancellation']);

        // System Modules & AI Engine Settings
        Route::get('modules', [AdminSystemSettingController::class, 'getModules']);
        Route::put('modules/{key}', [AdminSystemSettingController::class, 'updateModule']);
        Route::get('ai-config', [AdminSystemSettingController::class, 'getAiConfig']);
        Route::post('ai-config', [AdminSystemSettingController::class, 'updateAiConfig']);
        Route::post('ai-config/test', [AdminSystemSettingController::class, 'testAiConnection']);
    });



    // Disputes
    Route::prefix('disputes')->group(function () {
        Route::post('marketplace-refund', [DisputeController::class, 'storeRefund']);
        Route::post('opportunity-cancellation', [DisputeController::class, 'storeCancellation']);
        Route::get('{id}', [DisputeController::class, 'show']);
    });

    Route::get('/creators/{creatorId}/availability', [App\Http\Controllers\CreatorAvailabilityController::class, 'getAvailability']);
    
    // Protected creator profile endpoints
    Route::middleware('auth:api')->group(function () {
        Route::get('/profile', [App\Http\Controllers\ProfileController::class, 'getProfile']);
        Route::put('/profile', [App\Http\Controllers\ProfileController::class, 'updateProfile']);
        Route::get('/profile/identity', [App\Http\Controllers\ProfileController::class, 'identity']);
        Route::get('/profile/permissions', [App\Http\Controllers\ProfileController::class, 'permissions']);
        Route::get('/profile/history', [App\Http\Controllers\ProfileController::class, 'history']);
        
        // Creator Calendar
        Route::get('/profile/calendar', [App\Http\Controllers\CreatorCalendarController::class, 'index']);
        Route::post('/profile/calendar', [App\Http\Controllers\CreatorCalendarController::class, 'storeOrUpdate']);
        Route::delete('/profile/calendar/{date}', [App\Http\Controllers\CreatorCalendarController::class, 'destroy']);

    });

    // Marketplace (write operations)
    Route::prefix('marketplace')->middleware('module:marketplace_enabled')->group(function () {
        Route::post('/', [MarketplaceController::class, 'store']);
        Route::put('{id}', [MarketplaceController::class, 'update']);
        Route::delete('{id}', [MarketplaceController::class, 'destroy']);
        Route::post('{id}/publish', [MarketplaceController::class, 'publish']);
        Route::post('{id}/archive', [MarketplaceController::class, 'archive']);
        Route::post('{id}/review', [MarketplaceController::class, 'review']);
        Route::get('{id}/purchases', [MarketplaceController::class, 'purchases']);
        Route::post('{id}/purchase', [MarketplaceController::class, 'purchase']);
    });

    // Creator Services (write operations)
    Route::prefix('creator-services')->group(function () {
        Route::post('/', [\App\Http\Controllers\CreatorServiceController::class, 'store']);
        Route::put('{id}', [\App\Http\Controllers\CreatorServiceController::class, 'update']);
        Route::delete('{id}', [\App\Http\Controllers\CreatorServiceController::class, 'destroy']);
    });

    // Subscription (authenticated)
    Route::prefix('subscription')->group(function () {
        Route::post('purchase', [SubscriptionController::class, 'purchase']);
        Route::get('current', [SubscriptionController::class, 'getCurrent']);
    });

    // Storage Management
    Route::prefix('storage')->group(function () {
        Route::get('history', [StorageController::class, 'history']);
        Route::post('batch-delete', [StorageController::class, 'batchDestroy']);
        Route::post('clear-trash', [StorageController::class, 'clearTrash']);
        Route::post('batch-restore', [StorageController::class, 'batchRestore']);
        Route::post('batch-permanent-delete', [StorageController::class, 'batchForceDestroy']);
        Route::post('{id}/restore', [StorageController::class, 'restore']);
        Route::delete('{id}/permanent', [StorageController::class, 'forceDestroy']);
        Route::delete('{id}', [StorageController::class, 'destroy']);
        Route::get('{id}/download', [StorageController::class, 'download']);
        Route::get('{id}/view', [StorageController::class, 'view']);
        Route::post('purchased/{id}/retry', [StorageController::class, 'retryPurchasedClone']);
        Route::get('purchased/{id}/download', [StorageController::class, 'downloadPurchasedAsset']);
    });

    // AI Service (Protected)
    Route::prefix('ai')->middleware('module:ai_features_enabled')->group(function () {
        Route::post('summarize-report', [AiController::class, 'summarizeReport']);
        Route::post('recommendations', [AiController::class, 'getRecommendations']);
        Route::post('message-assistant', [AiController::class, 'messageAssistant']);
        Route::get('chat-sessions', [AiController::class, 'getChatSessions']);
        Route::post('chat-sessions', [AiController::class, 'syncChatSession']);
        Route::delete('chat-sessions/{sessionId}', [AiController::class, 'deleteChatSession']);
        Route::delete('chat-sessions', [AiController::class, 'clearChatSessions']);
    });
});

// Storage Management (Public Read for Status, View, and Download)
Route::get('storage/file/{id}/status', [StorageController::class, 'status']);
Route::get('storage/file/{id}/view', [StorageController::class, 'view']);
Route::get('storage/file/{id}/download', [StorageController::class, 'download']);
Route::get('storage/{id}/view', [StorageController::class, 'view']);
Route::get('storage/{id}/download', [StorageController::class, 'download']);

// Marketplace (public read)
Route::prefix('marketplace')->middleware('module:marketplace_enabled')->group(function () {
    Route::get('/', [MarketplaceController::class, 'index']);
    Route::get('featured', [MarketplaceController::class, 'featured']);
    Route::get('categories', [MarketplaceController::class, 'categories']);
    Route::get('{id}', [MarketplaceController::class, 'show']);
});

// Recommendations (Public Read)
Route::get('creators/recommendations', [\App\Http\Controllers\RecommendationController::class, 'getCreatorRecommendations']);
Route::get('creators/recommendations/categories', [\App\Http\Controllers\RecommendationController::class, 'getServiceCategories']);

// Creator Services (public read)
Route::prefix('creator-services')->group(function () {
    Route::get('/', [\App\Http\Controllers\CreatorServiceController::class, 'index']);
    Route::get('{id}', [\App\Http\Controllers\CreatorServiceController::class, 'show']);
});

// Subscription plans (public — prices are defined server-side, never trust the client)
Route::prefix('subscription')->group(function () {
    Route::get('plans', [SubscriptionController::class, 'plans']);
});

// Public Opportunities (Guest Browsing)
Route::prefix('opportunities')->group(function () {
    Route::get('/', [OpportunityController::class, 'index']);
    Route::get('map', [OpportunityController::class, 'mapLocations']);
    Route::get('{id}', [OpportunityController::class, 'show']);
    Route::get('{id}/poster', [OpportunityController::class, 'getPoster']);
});

// Public Client Dashboard Overview (Guest Browsing)
Route::get('client-dashboard/overview', [DashboardController::class, 'overview']);
Route::get('collaborations', [CollaborationController::class, 'index']);



