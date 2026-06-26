<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Cache;
use App\Models\Opportunity;
use App\Models\Report;
use App\Models\User;

class OpportunityController extends Controller
{
    public function index(Request $request)
    {
        $pihakSlug = $request->query('pihak_slug', 'all');
        $type = $request->query('type');
        $limit = (int) $request->query('limit', 50);

        $query = Opportunity::with('user:id,name,username,phone,email,avatar_url')
            ->where('status', 'open');

        if ($pihakSlug !== 'all') {
            $query->where('pihak_slug', $pihakSlug);
        }

        if ($type) {
            $query->where('type', $type);
        }

        $opportunities = $query->orderBy('created_at', 'desc')
            ->limit($limit)
            ->get()
            ->map(fn ($opp) => $this->formatOpportunity($opp));

        return response()->json([
            'success' => true,
            'data' => $opportunities,
        ]);
    }

    public function mapLocations(Request $request)
    {
        $pihakSlug = $request->query('pihak_slug', 'all');

        $query = Opportunity::with('user:id,name,username,phone,email,avatar_url')
            ->where('status', 'open')
            ->where('type', 'location')
            ->whereNotNull('latitude')
            ->whereNotNull('longitude');

        if ($pihakSlug !== 'all') {
            $query->where('pihak_slug', $pihakSlug);
        }

        $locations = $query->get()->map(fn ($opp) => $this->formatOpportunity($opp));

        return response()->json([
            'success' => true,
            'data' => $locations,
        ]);
    }

    public function show($id)
    {
        $opp = Opportunity::with('user:id,name,username,phone,email,avatar_url,selected_pihak')
            ->find($id);

        if (!$opp) {
            return response()->json([
                'success' => false,
                'message' => 'Peluang tidak ditemukan.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $this->formatOpportunity($opp, true),
        ]);
    }

    public function store(Request $request)
    {
        $user = Auth::guard('api')->user();

        $request->validate([
            'title' => 'required|string|max:200',
            'description' => 'nullable|string',
            'pihak_slug' => 'required|string|max:50',
            'type' => 'required|in:location,project',
            'location' => 'nullable|string|max:100',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'location_category' => 'nullable|string|max:50',
            'address' => 'nullable|string|max:255',
            'deadline' => 'nullable|date',
            'budget_range' => 'nullable|string|max:100',
        ]);

        $opp = Opportunity::create([
            'title' => $request->title,
            'description' => $request->description,
            'pihak_slug' => $request->pihak_slug,
            'type' => $request->type,
            'location' => $request->location,
            'latitude' => $request->latitude,
            'longitude' => $request->longitude,
            'location_category' => $request->location_category,
            'address' => $request->address,
            'deadline' => $request->deadline,
            'budget_range' => $request->budget_range,
            'status' => 'open',
            'posted_by' => $user->id,
            'created_at' => now(),
        ]);

        Cache::increment('opportunities_version');

        $opp->load('user:id,name,username,phone,email,avatar_url');

        return response()->json([
            'success' => true,
            'message' => 'Peluang berhasil dibuat.',
            'data' => $this->formatOpportunity($opp, true),
        ], 201);
    }

    public function submitReport(Request $request)
    {
        $user = Auth::guard('api')->user();

        $request->validate([
            'target_type' => 'required|in:opportunity,user',
            'target_id' => 'required|integer',
            'reason' => 'required|string|max:100',
            'description' => 'nullable|string|max:1000',
        ]);

        Report::create([
            'reporter_id' => $user->id,
            'target_type' => $request->target_type,
            'target_id' => $request->target_id,
            'reason' => $request->reason,
            'description' => $request->description,
            'status' => 'pending',
            'created_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Laporan berhasil dikirim. Tim kami akan meninjau segera.',
        ]);
    }

    private function formatOpportunity(Opportunity $opp, bool $fullDetail = false): array
    {
        $data = [
            'id' => $opp->id,
            'title' => $opp->title,
            'description' => $opp->description,
            'pihak_slug' => $opp->pihak_slug,
            'type' => $opp->type ?? 'project',
            'location' => $opp->location,
            'latitude' => $opp->latitude ? (float) $opp->latitude : null,
            'longitude' => $opp->longitude ? (float) $opp->longitude : null,
            'location_category' => $opp->location_category,
            'address' => $opp->address,
            'deadline' => $opp->deadline?->format('Y-m-d'),
            'budget_range' => $opp->budget_range,
            'status' => $opp->status,
            'posted_by' => $opp->posted_by,
            'created_at' => $opp->created_at?->toIso8601String(),
        ];

        if ($opp->relationLoaded('user') && $opp->user) {
            $data['poster'] = [
                'id' => $opp->user->id,
                'name' => $opp->user->name,
                'username' => $opp->user->username,
                'phone' => $opp->user->phone,
                'email' => $fullDetail ? $opp->user->email : null,
                'avatar_url' => $opp->user->avatar_url,
                'selected_pihak' => $opp->user->selected_pihak ?? null,
            ];
        }

        return $data;
    }
}
