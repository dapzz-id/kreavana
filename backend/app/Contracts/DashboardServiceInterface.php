<?php

namespace App\Contracts;

interface DashboardServiceInterface
{
    /**
     * Get statistics for dashboard based on sub-role and role type.
     *
     * @param string $subRoleSlug
     * @param string $roleType
     * @return array
     */
    public function getStats(string $subRoleSlug, string $roleType): array;

    /**
     * Get client dashboard overview.
     *
     * @param string $userId
     * @param string $roleType
     * @return array
     */
    public function getClientDashboardOverview(string $userId, string $roleType): array;
}
