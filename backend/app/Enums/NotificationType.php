<?php

namespace App\Enums;

enum NotificationType: string
{
    case Contract = 'contract';
    case Opportunity = 'opportunity';
    case Message = 'message';
    case Payment = 'payment';
    case Wallet = 'wallet';
    case Review = 'review';
    case System = 'system';
    case Success = 'success';
    case Info = 'info';
    case Warning = 'warning';
    case Error = 'error';
    case Project = 'project';
    case Location = 'location';
    case GroupInvite = 'group_invite';
    case CreatorApplied = 'creator_applied';
    case CreatorApproved = 'creator_approved';
    case CreatorRejected = 'creator_rejected';
    case ClientVerificationApplied = 'client_verification_applied';
    case ClientVerified = 'client_verified';
    case ClientRejected = 'client_rejected';
}
