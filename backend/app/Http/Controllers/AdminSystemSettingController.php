<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class AdminSystemSettingController extends Controller
{
    public function getPublicModuleStatuses()
    {
        return response()->json([
            'status' => true,
            'data' => [
                'ai_features_enabled' => true,
                'marketplace_enabled' => true,
                'collaboration_enabled' => true,
                'wallet_enabled' => true,
            ],
        ]);
    }
}
