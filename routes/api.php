<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\PointController;
use App\Http\Controllers\CommentController;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::get('/points', [PointController::class, 'index']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/points', [PointController::class, 'store']);
    Route::post('/comments', [CommentController::class, 'store']);
});