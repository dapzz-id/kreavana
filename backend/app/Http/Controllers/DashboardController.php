<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use App\Models\DashboardStat;
use App\Models\Opportunity;

class DashboardController extends Controller
{
    public function __construct()
    {
        $this->middleware('auth:api');
    }

    public function stats(Request $request)
    {
        $pihakSlug = $request->query('pihak_slug');
        $roleType = $request->query('role_type');

        if (!$pihakSlug || !$roleType) {
            return response()->json([
                'success' => false,
                'message' => 'Parameter pihak_slug dan role_type wajib diisi.'
            ], 400);
        }

        $version = Cache::get('dashboard_stats_version', 1);
        $cacheKey = "dashboard_stats_{$pihakSlug}_{$roleType}_v{$version}";

        $stats = Cache::remember($cacheKey, now()->addDays(1), function () use ($pihakSlug, $roleType) {
            return DashboardStat::where('pihak_slug', $pihakSlug)
                ->where('role_type', $roleType)
                ->orderBy('display_order')
                ->get();
        });

        return response()->json([
            'success' => true,
            'data' => $stats
        ]);
    }

    public function opportunities(Request $request)
    {
        $pihakSlug = $request->query('pihak_slug');

        if (!$pihakSlug) {
            return response()->json([
                'success' => false,
                'message' => 'Parameter pihak_slug wajib diisi.'
            ], 400);
        }

        $version = Cache::get('opportunities_version', 1);
        $cacheKey = "opportunities_{$pihakSlug}_v{$version}";

        $opportunities = Cache::remember($cacheKey, now()->addDays(1), function () use ($pihakSlug) {
            return Opportunity::where('pihak_slug', $pihakSlug)
                ->where('status', 'open')
                ->orderBy('created_at', 'desc')
                ->get();
        });

        return response()->json([
            'success' => true,
            'data' => $opportunities
        ]);
    }
}
