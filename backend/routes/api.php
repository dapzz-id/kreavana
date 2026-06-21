<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ChatController;
use App\Http\Controllers\MessageController;
use App\Http\Controllers\GroupController;

use App\Http\Controllers\UserController;

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
