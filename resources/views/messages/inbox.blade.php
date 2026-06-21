@extends('layouts.app')
@section('title', 'Pesan - KREAVANA')

@section('content')
<div class="max-w-2xl mx-auto px-4 py-8">
    <div class="flex items-center justify-between mb-8">
        <h1 class="text-2xl font-bold text-white">Pesan</h1>
        <span class="text-xs font-semibold text-indigo-400 bg-indigo-500/10 border border-indigo-500/20 px-3 py-1.5 rounded-full">
            {{ Auth::user()->unreadMessageCount() }} belum dibaca
        </span>
    </div>

    @if($conversations->isEmpty())
        <div class="flex flex-col items-center justify-center py-24 text-center bg-slate-800/40 rounded-3xl border border-slate-700">
            <div class="w-20 h-20 bg-slate-800 rounded-full flex items-center justify-center mb-5">
                <svg class="w-10 h-10 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/></svg>
            </div>
            <h2 class="text-xl font-bold text-gray-300">Belum Ada Pesan</h2>
            <p class="text-gray-500 text-sm mt-2">Mulai percakapan dengan fotografer atau sesama pengguna KREAVANA.</p>
            <a href="{{ route('explore') }}" class="mt-6 px-6 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl font-bold text-sm transition">
                Jelajahi & Temukan Fotografer
            </a>
        </div>
    @else
        <div class="space-y-2">
            @foreach($conversations as $convo)
            @php $partner = $convo['user']; $lastMsg = $convo['last_msg']; $unread = $convo['unread']; @endphp
            <a href="{{ route('messages.show', $partner->id) }}"
               class="flex items-center gap-4 p-4 rounded-2xl bg-slate-800/60 hover:bg-slate-700/80 border border-slate-700 hover:border-slate-600 transition-all group">
                <!-- Avatar -->
                <div class="relative flex-shrink-0">
                    <img src="{{ $partner->profile_photo_url }}" class="w-12 h-12 rounded-full object-cover" alt="">
                    @if($unread > 0)
                        <span class="absolute -top-1 -right-1 min-w-[18px] h-[18px] bg-indigo-500 text-white text-[10px] font-black rounded-full flex items-center justify-center px-1">
                            {{ $unread > 9 ? '9+' : $unread }}
                        </span>
                    @endif
                </div>
                <!-- Info -->
                <div class="flex-grow min-w-0">
                    <div class="flex justify-between items-baseline">
                        <p class="font-bold text-gray-100 text-sm {{ $unread ? 'text-white' : '' }}">{{ $partner->name }}</p>
                        @if($lastMsg)
                            <span class="text-xs text-gray-500 flex-shrink-0">{{ $lastMsg->created_at->diffForHumans(null, true) }}</span>
                        @endif
                    </div>
                    @if($lastMsg)
                        <p class="text-sm text-gray-400 truncate mt-0.5 {{ $unread ? 'text-gray-200 font-semibold' : '' }}">
                            @if($lastMsg->sender_id === Auth::id()) <span class="text-indigo-400">Anda: </span> @endif
                            {{ $lastMsg->body ?? '[Lampiran]' }}
                        </p>
                    @endif
                </div>
                <!-- Arrow -->
                <svg class="w-4 h-4 text-gray-600 group-hover:text-gray-400 flex-shrink-0 transition" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
            </a>
            @endforeach
        </div>
    @endif
</div>
@endsection
