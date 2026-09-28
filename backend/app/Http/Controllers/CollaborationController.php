<?php

namespace App\Http\Controllers;

use App\Models\Collaboration;
use App\Models\CollaborationMember;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class CollaborationController extends Controller
{
    public function index(Request $request)
    {
        $userId = Auth::id();

        $collaborations = Collaboration::with(['requester:id,name,avatar_url,sub_role,email,username', 'members.user:id,name,avatar_url,sub_role,email,username'])
            ->when($request->boolean('my_only') && $userId, function ($q) use ($userId) {
                $q->where(function ($sq) use ($userId) {
                    $sq->where('requester_id', $userId)
                      ->orWhereHas('members', function ($m) use ($userId) {
                          $m->where('user_id', $userId);
                      });
                });
            })
            ->when($request->filled('status') && $request->status !== 'Semua', function ($q) use ($request) {
                $statusMap = [
                    'Aktif' => 'active',
                    'Menunggu' => 'pending',
                    'Selesai' => 'completed',
                ];
                $s = $statusMap[$request->status] ?? strtolower($request->status);
                $q->where('status', $s);
            })
            ->orderByDesc('created_at')
            ->paginate($request->input('per_page', 50));

        $items = collect($collaborations->items())->map(function ($c) {
            $notes = json_decode($c->notes, true) ?? [];
            $neededRoles = $notes['neededRoles'] ?? [];
            if (empty($neededRoles) && $c->description) {
                if (preg_match('/Peran.*?: (.*)/i', $c->description, $matches)) {
                    $neededRoles = array_map('trim', explode(',', $matches[1]));
                }
            }

            $budgetStr = 'Rp ' . number_format($c->budget_min, 0, ',', '.');
            if ($c->budget_max && $c->budget_max > $c->budget_min) {
                $budgetStr .= ' - Rp ' . number_format($c->budget_max, 0, ',', '.');
            }

            $statusLabel = match ($c->status) {
                'active' => 'Aktif',
                'pending' => 'Menunggu',
                'completed' => 'Selesai',
                'rejected' => 'Ditolak',
                'cancelled' => 'Dibatalkan',
                default => ucfirst($c->status),
            };

            $statusColor = match ($c->status) {
                'active' => '#10B981',
                'pending' => '#F59E0B',
                'completed' => '#6B7280',
                default => '#EF4444',
            };

            $startDate = $c->start_date ? \Carbon\Carbon::parse($c->start_date)->translatedFormat('d M') : null;
            $endDate = $c->end_date ? \Carbon\Carbon::parse($c->end_date)->translatedFormat('d M Y') : null;
            $dateLabel = ($startDate && $endDate) ? "$startDate - $endDate" : ($endDate ?? $startDate ?? $c->created_at->translatedFormat('d M Y'));

            return [
                'id' => $c->id,
                'user_id' => $c->requester_id,
                'name' => $c->requester->name ?? 'Kreator Kreavana',
                'email' => $c->requester->email ?? '',
                'username' => $c->requester->username ?? '',
                'role' => $c->requester->sub_role ? ucwords(str_replace('_', ' ', $c->requester->sub_role)) : 'Kreator',
                'avatar' => $c->requester->avatar_url ?? null,
                'project' => $c->project_title,
                'desc' => $c->description ?? '',
                'neededRoles' => $neededRoles,
                'budget' => $budgetStr,
                'compensationType' => $notes['compensationType'] ?? 'Escrow Kreavana',
                'status' => $statusLabel,
                'statusColor' => $statusColor,
                'membersCount' => $c->members->where('status', 'active')->count() ?: 1,
                'maxMembers' => $notes['maxMembers'] ?? max(count($neededRoles) + 1, 3),
                'date' => $dateLabel,
                'location' => $c->project_location ?? 'Indonesia',
                'tags' => $notes['tags'] ?? ['Kolaborasi', 'Kreavana'],
                'members' => $c->members->map(function ($m) {
                    return [
                        'user_id' => $m->user_id,
                        'name' => $m->user->name ?? 'Member',
                        'role' => $m->role,
                        'status' => $m->status,
                        'avatar' => $m->user->avatar_url ?? null,
                    ];
                }),
            ];
        });

        return response()->json([
            'status' => true,
            'data' => $items,
            'meta' => [
                'current_page' => $collaborations->currentPage(),
                'total' => $collaborations->total(),
            ],
        ]);
    }

    public function store(Request $request)
    {
        $request->validate([
            'project_title'    => 'required|string|max:200',
            'description'      => 'sometimes|string|max:2000',
            'project_location' => 'sometimes|string|max:200',
            'start_date'       => 'sometimes|date',
            'end_date'         => 'sometimes|date|after_or_equal:start_date',
            'budget_min'       => 'sometimes|numeric|min:0',
            'budget_max'       => 'sometimes|numeric|min:0|gte:budget_min',
            'notes'            => 'sometimes|string|max:1000',
            'invitees'         => 'sometimes|array',
            'invitees.*.user_id'   => 'required|uuid|exists:users,id',
            'invitees.*.role'      => 'sometimes|string|max:100',
        ]);

        return DB::transaction(function () use ($request) {
            $collaboration = Collaboration::create([
                'requester_id'     => Auth::id(),
                'project_title'    => $request->project_title,
                'description'      => $request->description,
                'project_location' => $request->project_location,
                'start_date'       => $request->start_date,
                'end_date'         => $request->end_date,
                'budget_min'       => $request->budget_min,
                'budget_max'       => $request->budget_max,
                'notes'            => $request->notes,
                'status'           => 'pending',
            ]);

            $members = [
                [
                    'collaboration_id' => $collaboration->id,
                    'user_id'          => Auth::id(),
                    'role'             => 'Project Owner',
                    'status'           => 'active',
                    'joined_at'        => now(),
                    'responded_at'     => now(),
                ],
            ];
            foreach ($request->input('invitees', []) as $inv) {
                if ($inv['user_id'] !== Auth::id()) {
                    $members[] = [
                        'collaboration_id' => $collaboration->id,
                        'user_id'          => $inv['user_id'],
                        'role'             => $inv['role'] ?? 'Team Member',
                        'status'           => 'invited',
                    ];
                }
            }
            CollaborationMember::insert($members);

            $collaboration->load(['requester:id,name,avatar_url,sub_role', 'members.user:id,name,avatar_url,sub_role']);

            return response()->json([
                'status'  => true,
                'message' => 'Kolaborasi berhasil dibuat.',
                'data'    => $collaboration,
            ], 201);
        });
    }

    public function show($id)
    {
        $userId = Auth::id();

        $collaboration = Collaboration::with(['requester:id,name,avatar_url,sub_role,email', 'members.user:id,name,avatar_url,sub_role,email'])
            ->where(function ($q) use ($userId) {
                $q->where('requester_id', $userId)
                  ->orWhereHas('members', function ($m) use ($userId) {
                      $m->where('user_id', $userId);
                  });
            })
            ->where('id', $id)
            ->firstOrFail();

        return response()->json([
            'status' => true,
            'data' => $collaboration,
        ]);
    }

    public function respond(Request $request, $id)
    {
        $request->validate([
            'accept'  => 'required|boolean',
            'reason'  => 'sometimes|string|max:1000',
        ]);

        $userId = Auth::id();
        $now = now();

        $member = CollaborationMember::where('collaboration_id', $id)
            ->where('user_id', $userId)
            ->whereIn('status', ['invited', 'pending'])
            ->firstOrFail();

        $accepted = $request->boolean('accept');

        DB::transaction(function () use ($member, $accepted, $request, $now) {
            $member->update([
                'status'       => $accepted ? 'active' : 'rejected',
                'responded_at' => $now,
                'joined_at'    => $accepted ? $now : null,
            ]);

            $collab = $member->collaboration;
            $anyAccepted = $collab->members()->where('status', 'active')->count() > 1;

            $newStatus = match (true) {
                $accepted && $anyAccepted  => 'active',
                ! $accepted && $collab->status === 'pending' => 'pending',
                default => $collab->status,
            };

            if ($newStatus !== $collab->status) {
                $collab->update([
                    'status'        => $newStatus,
                    'responded_at'  => $now,
                    'reject_reason' => $accepted ? null : ($request->reason ?? null),
                ]);
            } elseif (! $accepted) {
                $collab->update([
                    'reject_reason' => $request->reason ?? $collab->reject_reason,
                ]);
            }
        });

        return response()->json([
            'status'  => true,
            'message' => $accepted ? 'Undangan kolaborasi diterima.' : 'Undangan kolaborasi ditolak.',
        ]);
    }

    public function update(Request $request, $id)
    {
        $collaboration = Collaboration::where('id', $id)
            ->where('requester_id', Auth::id())
            ->firstOrFail();

        $request->validate([
            'project_title'    => 'sometimes|string|max:200',
            'description'      => 'sometimes|string|max:2000',
            'project_location' => 'sometimes|string|max:200',
            'start_date'       => 'sometimes|date',
            'end_date'         => 'sometimes|date|after_or_equal:start_date',
            'budget_min'       => 'sometimes|numeric|min:0',
            'budget_max'       => 'sometimes|numeric|min:0|gte:budget_min',
            'status'           => 'sometimes|in:pending,active,completed,cancelled',
            'notes'            => 'sometimes|string|max:1000',
        ]);

        $collaboration->update($request->only([
            'project_title', 'description', 'project_location',
            'start_date', 'end_date', 'budget_min', 'budget_max',
            'status', 'notes',
        ]));

        return response()->json([
            'status'  => true,
            'message' => 'Kolaborasi berhasil diperbarui.',
            'data'    => $collaboration,
        ]);
    }

    public function destroy($id)
    {
        $collaboration = Collaboration::where('id', $id)
            ->where('requester_id', Auth::id())
            ->firstOrFail();

        $collaboration->delete();

        return response()->json([
            'status'  => true,
            'message' => 'Kolaborasi berhasil dihapus.',
        ]);
    }
}
