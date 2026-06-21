<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\HomeController;
use App\Http\Controllers\CartController;
use App\Http\Controllers\PaymentController;
use App\Http\Controllers\PhotographerController;
use App\Http\Controllers\AdminController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\MessageController;
use App\Http\Controllers\StoryController;
use App\Http\Controllers\NotificationController;

// ─── 1. Landing Page (Public) ────────────────────────────────────────────────
Route::get('/', fn () => view('welcome'))->name('home');

// ─── 2. Main Feed / Explore (Public) ─────────────────────────────────────────
Route::match(['get', 'post'], '/explore', [HomeController::class, 'index'])->name('explore');
Route::get('/photo/{id}', [HomeController::class, 'showPhoto'])->name('photo.show');
Route::get('/find-photographers', [HomeController::class, 'showMap'])->name('photographers.map');

// ─── 3. Authentication Routes (Guest Only) ───────────────────────────────────
Route::middleware('guest')->group(function () {
    Route::get('/login', [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [AuthController::class, 'login']);
    Route::get('/register', [AuthController::class, 'showRegister'])->name('register');
    Route::post('/register', [AuthController::class, 'register']);

    // Google SSO
    Route::get('/auth/google', [AuthController::class, 'redirectToGoogle'])->name('auth.google');
    Route::get('/auth/google/callback', [AuthController::class, 'handleGoogleCallback'])->name('auth.google.callback');
});

// ─── 4. Authenticated Routes ──────────────────────────────────────────────────
Route::middleware('auth')->group(function () {

    // Dashboard
    Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');

    // Logout
    Route::post('/logout', [AuthController::class, 'logout'])->name('logout');

    // ── Notifications ────────────────────────────────────────────────────────
    Route::get('/notifications', [NotificationController::class, 'index'])->name('notifications.index');
    Route::post('/notifications/{id}/read', [NotificationController::class, 'markAsRead'])->name('notifications.read');
    Route::post('/notifications/read-all', [NotificationController::class, 'markAllAsRead'])->name('notifications.read_all');

    // ── Profile ──────────────────────────────────────────────────────────────
    Route::get('/profile/edit', [ProfileController::class, 'show'])->name('profile.edit');
    Route::get('/profile/{username?}', [ProfileController::class, 'index'])->name('profile');
    Route::post('/profile/update', [ProfileController::class, 'update'])->name('profile.update');
    Route::post('/profile/photo', [ProfileController::class, 'updatePhoto'])->name('profile.photo');
    Route::post('/profile/password', [ProfileController::class, 'updatePassword'])->name('profile.password');
    Route::post('/profile/face-scan', [ProfileController::class, 'storeFaceEmbedding'])->name('profile.face_scan');
    Route::post('/profile/request-photographer', [HomeController::class, 'requestPhotographer'])->name('profile.request_photographer');
    Route::post('/user/follow/{id}', [HomeController::class, 'followUser'])->name('user.follow');

    // ── Stories ───────────────────────────────────────────────────────────────
    Route::post('/stories', [StoryController::class, 'store'])->name('stories.store');
    Route::get('/stories/{story}', [StoryController::class, 'view'])->name('stories.view');
    Route::delete('/stories/{story}', [StoryController::class, 'destroy'])->name('stories.destroy');

    // ── Direct Messages ───────────────────────────────────────────────────────
    Route::get('/messages', [MessageController::class, 'inbox'])->name('messages.inbox');
    Route::get('/messages/{user}', [MessageController::class, 'show'])->name('messages.show');
    Route::post('/messages/{user}/send', [MessageController::class, 'send'])->name('messages.send');
    Route::get('/messages/{user}/poll', [MessageController::class, 'poll'])->name('messages.poll');

    // ── Social Interactions ───────────────────────────────────────────────────
    Route::post('/photo/like/{id}', [HomeController::class, 'likePhoto'])->name('photo.like');
    Route::post('/photo/comment/{id}', [HomeController::class, 'commentPhoto'])->name('photo.comment');
    Route::post('/photo/save/{id}', [HomeController::class, 'savePhoto'])->name('photo.save');
    Route::get('/photo/download/{id}', [HomeController::class, 'downloadPhoto'])->name('photo.download');

    // ── Cart ──────────────────────────────────────────────────────────────────
    Route::prefix('cart')->name('cart.')->group(function () {
        Route::get('/', [CartController::class, 'index'])->name('index');
        Route::post('/add/{id}', [CartController::class, 'add'])->name('add');
        Route::post('/remove/{id}', [CartController::class, 'remove'])->name('remove');
        Route::post('/clear', [CartController::class, 'clear'])->name('clear');
    });

    // ── Balance & Payments ────────────────────────────────────────────────────
    Route::get('/balance/topup', [PaymentController::class, 'showTopUp'])->name('payment.topup');
    Route::post('/balance/topup/process', [PaymentController::class, 'processTopUp'])->name('payment.topup.process');
    Route::post('/cart/checkout', [PaymentController::class, 'checkout'])->name('cart.checkout');
});

// ─── 5. Photographer Protected Routes ────────────────────────────────────────
Route::middleware(['auth', 'role:photographer'])->prefix('photographer')->name('photographer.')->group(function () {
    Route::get('/dashboard', [PhotographerController::class, 'dashboard'])->name('dashboard');
    Route::post('/upload', [PhotographerController::class, 'uploadPhoto'])->name('upload');
});

// ─── 6. Superadmin Protected Routes ──────────────────────────────────────────
Route::middleware(['auth', 'role:superadmin'])->prefix('admin')->name('admin.')->group(function () {
    Route::get('/dashboard', [AdminController::class, 'dashboard'])->name('dashboard');
    Route::post('/request/approve/{id}', [AdminController::class, 'approveRequest'])->name('approve');
    Route::post('/request/reject/{id}', [AdminController::class, 'rejectRequest'])->name('reject');
    Route::get('/request/document/{id}/{type}', [AdminController::class, 'viewDocument'])->name('document');
});

// ─── 7. Public Midtrans Webhook (CSRF excluded in bootstrap/app.php) ─────────
Route::post('/api/midtrans/webhook', [PaymentController::class, 'midtransWebhook'])->name('payment.webhook');
