<?php

namespace App\Enums;

enum ConversationType: string
{
    case Personal = 'personal';
    case Group = 'group';
    case Direct = 'direct';
}
