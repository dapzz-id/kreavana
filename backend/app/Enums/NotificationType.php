<?php

namespace App\Enums;

enum NotificationType: string
{
    case Contract = 'contract';
    case Opportunity = 'opportunity';
    case Message = 'message';
    case Payment = 'payment';
    case Review = 'review';
    case System = 'system';
    case Success = 'success';
    case Info = 'info';
    case Warning = 'warning';
    case Error = 'error';
    case Project = 'project';
    case Location = 'location';
}
