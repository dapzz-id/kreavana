<?php

namespace App\Enums;

enum RoleType: string
{
    case Admin = 'admin';
    case User = 'user';
    case Creator = 'creator';
}
