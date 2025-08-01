<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $attrs = $request->validate([
            'username' => 'required|unique:users',
            'password' => 'required|digits_between:4,8',
        ]);
        $user = User::create([
    'username' => $request->username,
    'password' => bcrypt($request->password),
    // (или email если у тебя email, а не username)
]);
// ...
return response()->json([
   'token' => $user->createToken('main')->plainTextToken,
   'user' => $user,
]);
    }

    public function login(Request $request)
    {
        $attrs = $request->validate([
            'username' => 'required|exists:users,username',
            'password' => 'required|digits_between:4,8',
        ]);
        $user = User::where('username', $attrs['username'])->first();
        if (!Hash::check($attrs['password'], $user->password)) {
            return response(['message' => 'Invalid credentials'], 403);
        }
        return response([
            'user' => $user,
            'token' => $user->createToken('main')->plainTextToken,
        ]);
    }
}