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
    case TUKANG_KENDANG = 'tukang_kendang';
    case CONTENT_CREATOR = 'content_creator';
    case ANIMATOR = 'animator';
    case DESIGNER = 'designer';
    case MUSICIAN = 'musician';
    case TALENT = 'talent';
    case DRONE_PILOT = 'drone_pilot';

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
            self::TUKANG_KENDANG => 'Tukang Kendang',
            self::CONTENT_CREATOR => 'Content Creator',
            self::ANIMATOR => 'Animator',
            self::DESIGNER => 'Designer',
            self::MUSICIAN => 'Musician',
            self::TALENT => 'Talent',
            self::DRONE_PILOT => 'Drone Pilot',
        };
    }
}
