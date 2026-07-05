<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\GroupService;
use App\Http\Requests\CreateGroupRequest;
use App\Http\Requests\AddGroupMemberRequest;
use App\Traits\ApiResponse;
use App\Models\Chat;

class GroupController extends Controller
{
    use ApiResponse;

    protected GroupService $groupService;

    public function __construct(GroupService $groupService)
    {
        $this->groupService = $groupService;
    }

    public function store(CreateGroupRequest $request)
    {
        $userId = $request->user()->id;
        $group = $this->groupService->createGroup($userId, $request->validated());

        return $this->successResponse('Grup berhasil dibuat', $group, 201);
    }

    public function members(Chat $chat)
    {
        $members = $this->groupService->getMembers($chat);

        return $this->successResponse('Anggota grup berhasil diambil', $members);
    }

    public function addMember(AddGroupMemberRequest $request, Chat $chat)
    {
        $this->groupService->addMember($chat, $request->user_id);

        return $this->successResponse('Undangan berhasil dikirim');
    }

    public function updateSettings(Request $request, Chat $chat)
    {
        $request->validate(['only_admin_can_add' => 'required|boolean']);
        $this->groupService->updateSettings($chat, $request->only('only_admin_can_add'));

        return $this->successResponse('Pengaturan berhasil diperbarui');
    }

    public function updateGroupDetails(Request $request, Chat $chat)
    {
        $request->validate([
            'name' => 'required|string|max:100',
            'description' => 'nullable|string|max:500',
        ]);

        $chatData = $this->groupService->updateDetails($chat, $request->only('name', 'description'));

        return $this->successResponse('Detail grup berhasil diperbarui', $chatData);
    }

    public function kickMember(Chat $chat, $userId)
    {
        $this->groupService->kickMember($chat, $userId);

        return $this->successResponse('Anggota dikeluarkan');
    }

    public function makeAdmin(Chat $chat, $userId)
    {
        $this->groupService->makeAdmin($chat, $userId);

        return $this->successResponse('Anggota dijadikan admin');
    }

    public function leaveGroup(Request $request, Chat $chat)
    {
        $userId = $request->user()->id;
        $this->groupService->leaveGroup($chat, $userId);

        return $this->successResponse('Berhasil keluar dari grup');
    }

    public function getInvitations(Request $request)
    {
        $userId = $request->user()->id;
        $invitations = $this->groupService->getInvitations($userId);

        return $this->successResponse('Undangan berhasil diambil', $invitations);
    }

    public function respondInvitation(Request $request, Chat $chat)
    {
        $userId = $request->user()->id;
        $request->validate(['accept' => 'required|boolean']);

        $this->groupService->respondInvitation($chat, $userId, $request->accept);

        $message = $request->accept ? 'Undangan diterima' : 'Undangan ditolak';
        return $this->successResponse($message);
    }
}
