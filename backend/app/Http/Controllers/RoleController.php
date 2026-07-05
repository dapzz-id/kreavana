<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Enums\CreatorSubRole;
use App\Traits\ApiResponse;

class RoleController extends Controller
{
    use ApiResponse;

    /**
     * Get available sub-roles for creator.
     */
    public function getCreatorSubRoles()
    {
        $subRoles = collect(CreatorSubRole::cases())->map(function ($case) {
            return [
                'value' => $case->value,
                'label' => $case->label(),
            ];
        });

        return $this->successResponse('Sub-role berhasil diambil', $subRoles->toArray());
    }
}
