<?php

namespace App\Http\Controllers;

use App\Models\Point;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;

class PointController extends Controller
{
    public function index()
{
    // Получаем все точки, user, comments
    $points = \App\Models\Point::with(['user', 'comments'])->get();
    return response()->json($points);
}
    public function store(Request $request)
{
    $attrs = $request->validate([
        'name'        => 'required',
        'description' => 'required',
        'lat'         => 'required|numeric',
        'lng'         => 'required|numeric',
        'type'        => 'required|in:green,yellow,red',
    ]);

    // 1. Создаём точку без поля location (нельзя сюда DB::raw!)
    $point = \App\Models\Point::create([
        'user_id'    => \Auth::id(),
        'name'       => $attrs['name'],
        'description'=> $attrs['description'],
        'type'       => $attrs['type'],
        // 'location' НЕ передаём!
    ]);

    // 2. Сразу после создания патчим location через DB::raw (PostGIS)
    \DB::table('points')
        ->where('id', $point->id)
        ->update([
            'location' => \DB::raw("ST_MakePoint({$attrs['lng']}, {$attrs['lat']})")
        ]);
    $point->refresh();

    // 3. Далее — обратное геокодирование (можно временно withoutVerifying, если SSL)
    try {
        $response = \Http::withoutVerifying()->get(
            "https://nominatim.openstreetmap.org/reverse",
            [
                'lat' => $attrs['lat'],
                'lon' => $attrs['lng'],
                'format' => 'json'
            ]
        );
        $point->address = $response['display_name'] ?? null;
        $point->save();
    } catch (\Throwable $e) {
        // В случае сбоя адрес будет пустым
        $point->address = null;
        $point->save();
    }

    // 4. Инкрементируем points_created только после всего выше
    $user = \Auth::user();
    $user->increment('points_created');

    return $point->load('user', 'comments');
}
}