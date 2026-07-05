<?php

namespace App\Enums;

enum CreatorSubRole: string
{
    case INSTITUTION = 'institution';
    case GOVERNMENT = 'government';
    case MC = 'mc';
    case SINGER = 'singer';
    case WEDDING_ORGANIZER = 'wedding_organizer';
    case EVENT_ORGANIZER = 'event_organizer';
    case COMMUNITY = 'community';
    case MAKEUP_ARTIST = 'makeup_artist';
    case PHOTOGRAPHER = 'photographer';
    case EDITOR = 'editor';
    case VIDEOGRAPHER = 'videographer';

    public function label(): string
    {
        return match($this) {
            self::INSTITUTION => 'Institution',
            self::GOVERNMENT => 'Government',
            self::MC => 'MC',
            self::SINGER => 'Singer',
            self::WEDDING_ORGANIZER => 'Wedding Organizer',
            self::EVENT_ORGANIZER => 'Event Organizer',
            self::COMMUNITY => 'Community',
            self::MAKEUP_ARTIST => 'Makeup Artist',
            self::PHOTOGRAPHER => 'Photographer',
            self::EDITOR => 'Editor',
            self::VIDEOGRAPHER => 'Videographer',
        };
    }
}
