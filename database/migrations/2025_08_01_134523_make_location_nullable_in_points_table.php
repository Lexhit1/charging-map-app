<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up()
{
    \DB::statement('ALTER TABLE points ALTER COLUMN location DROP NOT NULL;');
}

public function down()
{
    \DB::statement('ALTER TABLE points ALTER COLUMN location SET NOT NULL;');
}

};