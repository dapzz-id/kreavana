<?php

namespace App\Enums;

enum MessageType: string
{
    case Text = 'text';
    case Audio = 'audio';
    case Image = 'image';
    case File = 'file';
    case System = 'system';
}
