<?php

namespace App\Enums;

enum WorkStatus: string
{
    case Pending = 'pending';
    case Scheduled = 'scheduled';
    case InProgress = 'in_progress';
    case Submitted = 'submitted';
    case Revision = 'revision';
    case Done = 'done';
    case Completed = 'completed';
    case Review = 'review';
    case Cancelled = 'cancelled';
}
