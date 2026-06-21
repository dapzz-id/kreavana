@extends('layouts.app')
@section('title', 'Eksplorasi - KREAVANA')

@section('styles')
<style>
    /* CSS Watermark */
    .wm-overlay {
        background-image: repeating-linear-gradient(-45deg, transparent, transparent 100px, rgba(255,255,255,0.08) 100px, rgba(255,255,255,0.08) 101px);
        z-index: 2;
    }
    .wm-overlay::before {
        content: 'KREAVANA';
        position: absolute; inset: -50%; display: flex; flex-wrap: wrap; align-content: center; justify-content: center;
        font-size: 20px; font-weight: 900; letter-spacing: 10px; line-height: 4;
        color: rgba(255, 255, 255, 0.2); text-transform: uppercase; transform: rotate(-30deg);
        pointer-events: none; user-select: none; word-spacing: 80px; overflow: hidden;
    }
    /* Masonry style feed */
    .explore-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
        gap: 0.75rem;
        align-items: start;
    }
    @media (min-width: 768px) {
        .explore-grid {
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 1.5rem;
        }
    }
    .explore-card {
        break-inside: avoid;
    }
</style>
@endsection

@section('content')
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">

    <!-- Header & Search -->
    <div class="mb-8">
        <h1 class="text-3xl md:text-5xl font-black text-white tracking-tight mb-3">Eksplorasi Karya</h1>
        <p class="text-gray-400 text-sm md:text-base">Temukan inspirasi visual terbaik dari ribuan fotografer.</p>
        
        <div class="mt-8 flex flex-col md:flex-row gap-4 items-center">
            <form action="{{ route('explore') }}" method="GET" class="relative w-full md:flex-1 max-w-2xl">
                <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                    <svg class="h-5 w-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>
                </div>
                <input type="text" name="q" value="{{ request('q') }}"
                       class="w-full pl-12 pr-24 py-3.5 bg-slate-800/80 border border-slate-700/50 rounded-2xl text-gray-200 placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition shadow-inner text-sm backdrop-blur-md"
                       placeholder="Cari foto, event, atau fotografer...">
                <button type="submit" class="absolute inset-y-1.5 right-1.5 bg-indigo-600 hover:bg-indigo-500 text-white px-6 rounded-xl text-sm font-bold transition shadow-lg shadow-indigo-500/20">
                    Cari
                </button>
            </form>
        </div>

        <!-- Filter Pills -->
        <div class="mt-6 flex gap-3 overflow-x-auto pb-2 scrollbar-hide">
            <a href="{{ route('explore') }}" class="px-5 py-2 rounded-full whitespace-nowrap text-sm font-bold {{ !request('q') ? 'bg-white text-slate-900' : 'bg-slate-800 text-gray-400 hover:bg-slate-700 hover:text-white' }} transition">Semua</a>
            <a href="{{ route('explore', ['q' => 'wedding']) }}" class="px-5 py-2 rounded-full whitespace-nowrap text-sm font-semibold {{ request('q') == 'wedding' ? 'bg-white text-slate-900' : 'bg-slate-800 text-gray-400 hover:bg-slate-700 hover:text-white' }} transition border border-slate-700">Wedding</a>
            <a href="{{ route('explore', ['q' => 'wisuda']) }}" class="px-5 py-2 rounded-full whitespace-nowrap text-sm font-semibold {{ request('q') == 'wisuda' ? 'bg-white text-slate-900' : 'bg-slate-800 text-gray-400 hover:bg-slate-700 hover:text-white' }} transition border border-slate-700">Wisuda</a>
            <a href="{{ route('explore', ['q' => 'konser']) }}" class="px-5 py-2 rounded-full whitespace-nowrap text-sm font-semibold {{ request('q') == 'konser' ? 'bg-white text-slate-900' : 'bg-slate-800 text-gray-400 hover:bg-slate-700 hover:text-white' }} transition border border-slate-700">Konser</a>
            <a href="{{ route('explore', ['q' => 'studio']) }}" class="px-5 py-2 rounded-full whitespace-nowrap text-sm font-semibold {{ request('q') == 'studio' ? 'bg-white text-slate-900' : 'bg-slate-800 text-gray-400 hover:bg-slate-700 hover:text-white' }} transition border border-slate-700">Studio</a>
        </div>
    </div>

    <!-- Feed -->
    @if(isset($photos) && $photos->isEmpty())
        <div class="flex flex-col items-center justify-center py-32 bg-slate-800/20 rounded-3xl border border-slate-800/50">
            <div class="w-20 h-20 rounded-full border-2 border-slate-700 flex items-center justify-center mb-6">
                <svg class="w-10 h-10 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>
            </div>
            <h3 class="text-2xl font-black text-gray-300">Pencarian Tidak Ditemukan</h3>
            <p class="text-base text-gray-500 mt-2">Coba gunakan kata kunci lain atau pilih kategori di atas.</p>
        </div>
    @else
        <div class="explore-grid">
            @foreach($photos as $photo)
                @php 
                    $ownsPhoto = Auth::check() && $photo->user_id === Auth::id();
                    $purchased = Auth::check() && Auth::user()->hasPurchased($photo->id);
                    $isForSale = $photo->is_for_sale && $photo->price > 0;
                    $needsWatermark = $isForSale && !$ownsPhoto && !$purchased;
                @endphp

                <div class="explore-card group bg-slate-900/50 rounded-[2rem] overflow-hidden border border-slate-800 hover:border-indigo-500/50 transition-all duration-300 shadow-xl hover:shadow-indigo-500/10 relative">
                    
                    <!-- Photo Header (Absolute on top of image for cleaner look) -->
                    <div class="absolute top-0 left-0 w-full p-4 flex items-center justify-between z-10 bg-gradient-to-b from-black/70 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                        <a href="#" class="flex items-center gap-2">
                            <img src="{{ $photo->photographer->profile_photo_url ?? 'https://ui-avatars.com/api/?name=U' }}" 
                                 class="w-8 h-8 rounded-full object-cover ring-2 ring-white/20">
                            <span class="text-sm font-bold text-white shadow-black drop-shadow-md">{{ $photo->photographer->name ?? 'Unknown' }}</span>
                        </a>
                        <span class="text-xs font-bold text-white/80 bg-black/40 px-2 py-1 rounded-md backdrop-blur-sm">{{ $photo->created_at->diffForHumans(null, true) }}</span>
                    </div>

                    <!-- Photo Image -->
                    <div class="relative bg-slate-950">
                        <img src="{{ asset('storage/' . ($photo->watermarked_path ?? '')) }}" 
                             alt="{{ $photo->title }}" 
                             class="w-full h-auto object-cover group-hover:scale-105 transition-transform duration-700"
                             loading="lazy"
                             @if($needsWatermark) draggable="false" oncontextmenu="return false;" @endif>
                        
                        @if($needsWatermark)
                            <div class="absolute inset-0 pointer-events-none wm-overlay"></div>
                            
                            <!-- Hover Action (Add to Cart / Buy) -->
                            <div class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center backdrop-blur-[2px]">
                                <div class="flex flex-col items-center gap-4 transform translate-y-4 group-hover:translate-y-0 transition-all duration-300">
                                    <span class="px-5 py-2 rounded-2xl bg-black/80 border border-white/10 text-white font-black text-xl shadow-2xl backdrop-blur-md">
                                        Rp {{ number_format($photo->price, 0, ',', '.') }}
                                    </span>
                                    <form action="{{ route('cart.add', $photo->id) }}" method="POST">
                                        @csrf
                                        <button type="submit" class="px-8 py-3 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-xl text-sm shadow-[0_0_20px_rgba(79,70,229,0.5)] transition hover:scale-105 active:scale-95 flex items-center gap-2">
                                            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 4v16m8-8H4"/></svg>
                                            Keranjang
                                        </button>
                                    </form>
                                </div>
                            </div>
                        @endif
                    </div>

                    <!-- Photo Footer / Actions -->
                    <div class="p-4">
                        <div class="flex items-center justify-between mb-3">
                            <div class="flex items-center gap-4">
                                <!-- Like Button (Visual Only for now) -->
                                <button class="text-gray-400 hover:text-pink-500 transition">
                                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"/></svg>
                                </button>
                                <!-- Comment Button -->
                                <button class="text-gray-400 hover:text-white transition">
                                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/></svg>
                                </button>
                                <!-- DM Photographer -->
                                @if(Auth::check() && Auth::id() !== $photo->user_id)
                                <a href="{{ route('messages.show', $photo->user_id) }}" class="text-gray-400 hover:text-indigo-400 transition" title="Kirim Pesan">
                                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"/></svg>
                                </a>
                                @endif
                            </div>
                            <!-- Save Button -->
                            <button class="text-gray-400 hover:text-white transition">
                                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"/></svg>
                            </button>
                        </div>

                        <a href="{{ route('photo.show', $photo->id) }}" class="text-sm font-bold text-gray-200 hover:text-white line-clamp-1 mb-1">{{ $photo->title }}</a>
                        @if($photo->description)
                            <p class="text-xs text-gray-400 line-clamp-2">{{ $photo->description }}</p>
                        @endif

                        @if($purchased || $ownsPhoto || !$isForSale)
                            <a href="{{ route('photo.download', $photo->id) }}" class="mt-4 w-full py-2 bg-slate-700 hover:bg-slate-600 text-white text-xs font-bold rounded-xl flex items-center justify-center gap-2 transition">
                                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/></svg>
                                Unduh Asli
                            </a>
                        @else
                            <div class="mt-4 pt-3 border-t border-slate-800 flex items-center justify-between">
                                <div class="text-sm font-black text-indigo-400">
                                    Rp {{ number_format($photo->price, 0, ',', '.') }}
                                </div>
                                <form action="{{ route('cart.add', $photo->id) }}" method="POST">
                                    @csrf
                                    <button type="submit" class="px-4 py-1.5 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold rounded-lg transition flex items-center gap-1.5 shadow-lg shadow-indigo-500/20 hover:scale-105">
                                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"/></svg>
                                        Keranjang
                                    </button>
                                </form>
                            </div>
                        @endif
                    </div>
                </div>
            @endforeach
        </div>
    @endif
</div>
@endsection
