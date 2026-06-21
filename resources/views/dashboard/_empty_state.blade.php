{{--
    Reusable empty state partial.
    Props: $icon (camera|bag|bookmark), $title, $subtitle, $action_url (optional), $action_label (optional)
--}}
@php
    $icons = [
        'camera' => '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"/>',
        'bag'    => '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/>',
        'bookmark'=> '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"/>',
    ];
    $svgPath = $icons[$icon ?? 'camera'] ?? $icons['camera'];
@endphp

<div class="flex flex-col items-center justify-center py-20 text-center">
    <div class="w-16 h-16 rounded-full border-2 border-slate-600 flex items-center justify-center mb-5">
        <svg class="w-8 h-8 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">{!! $svgPath !!}</svg>
    </div>
    <h3 class="text-xl font-bold text-gray-300">{{ $title }}</h3>
    <p class="text-sm text-gray-500 mt-2 max-w-xs">{{ $subtitle }}</p>
    @if(isset($action_url) && $action_url)
        <a href="{{ $action_url }}" class="mt-5 px-6 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-sm font-bold transition">
            {{ $action_label ?? 'Mulai' }}
        </a>
    @endif
</div>
