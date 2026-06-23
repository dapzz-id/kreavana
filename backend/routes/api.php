<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ChatController;
use App\Http\Controllers\MessageController;
use App\Http\Controllers\GroupController;

use App\Http\Controllers\UserController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\AdminController;
Route::get('/user', function (Request $request) {
    return $request->user();
})->middleware('auth:sanctum');

// Menggunakan user ID 1 untuk prototyping
Route::get('/users/search', [UserController::class, 'search']);

Route::get('/chats', [ChatController::class, 'index']);
Route::post('/chats/personal', [ChatController::class, 'startPersonalChat']);
Route::get('/chats/{chat}/messages', [MessageController::class, 'index']);
Route::post('/chats/{chat}/messages', [MessageController::class, 'store']);

Route::get('/invitations', [GroupController::class, 'getInvitations']);
Route::post('/invitations/{chat}/respond', [GroupController::class, 'respondInvitation']);

Route::post('/groups', [GroupController::class, 'store']);
Route::get('/groups/{chat}/members', [GroupController::class, 'members']);
Route::post('/groups/{chat}/members', [GroupController::class, 'addMember']);
Route::delete('/groups/{chat}/members/{userId}', [GroupController::class, 'kickMember']);
Route::put('/groups/{chat}/members/{userId}/admin', [GroupController::class, 'makeAdmin']);
Route::post('/groups/{chat}/leave', [GroupController::class, 'leaveGroup']);
Route::put('/groups/{chat}/settings', [GroupController::class, 'updateSettings']);

// Auth Routes
Route::post('auth/login', [AuthController::class, 'login']);
Route::post('auth/register', [AuthController::class, 'register']);

Route::group(['middleware' => 'auth:api'], function() {
    Route::post('auth/logout', [AuthController::class, 'logout']);
    Route::post('auth/refresh', [AuthController::class, 'refresh']);
    Route::get('auth/me', [AuthController::class, 'me']);

    // Dashboard Routes
    Route::get('dashboard/stats', [DashboardController::class, 'stats']);
    Route::get('dashboard/opportunities', [DashboardController::class, 'opportunities']);

    // Profile Routes
    Route::get('profile', [ProfileController::class, 'getProfile']);
    Route::put('profile', [ProfileController::class, 'updateProfile']);
    Route::post('profile/apply-creator', [ProfileController::class, 'applyCreator']);

    // Notifications Routes
    Route::get('notifications', [NotificationController::class, 'index']);
    Route::put('notifications/read', [NotificationController::class, 'markAsRead']);

    // Admin Routes
    Route::get('admin/applications', [AdminController::class, 'getApplications']);
    Route::post('admin/applications/{id}/approve', [AdminController::class, 'approveApplication']);
    Route::post('admin/applications/{id}/reject', [AdminController::class, 'rejectApplication']);
});
