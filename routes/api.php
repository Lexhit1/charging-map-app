<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\PointController;
use App\Http\Controllers\CommentController;

Route::apiResource('points', PointController::class);
Route::get('points/nearest', [PointController::class, 'nearest']);
Route::post('comments', [CommentController::class, 'store']);