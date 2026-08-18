<?php

namespace App\Enums;

enum ContractStatus: string
{
    case Draft = 'draft';
    case Proposed = 'proposed';
    case Approved = 'approved';
    case EscrowPaid = 'escrow_paid';
    case Active = 'active';
    case Completed = 'completed';
    case Cancelled = 'cancelled';
    case CancelRequested = 'cancel_requested';
    case Disputed = 'disputed';
}
