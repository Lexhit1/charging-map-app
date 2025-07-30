<?php

namespace App\Http\Controllers;

use App\Models\Comment;
use Illuminate\Http\Request;

class CommentController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'point_id' => 'required|exists:points,id',
            'comment' => 'required',
        ]);

        return Comment::create($validated);
    }
}