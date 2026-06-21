@extends('layouts.app')
@section('title', 'Dashboard - KREAVANA')

@section('content')
@php 
    $me = Auth::user(); 
@endphp

<div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        
        <!-- LEFT COLUMN: FEED & STORIES (2/3 width) -->
        <div class="lg:col-span-2">
            
            <!-- Stories Section -->
            <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-4 mb-8 flex gap-4 overflow-x-auto scrollbar-hide shadow-sm">
                <!-- User's own story upload button -->
                <div class="flex flex-col items-center flex-shrink-0 cursor-pointer" onclick="document.getElementById('story-modal').classList.remove('hidden')">
                    <div class="w-16 h-16 rounded-full border-2 border-dashed border-slate-300 dark:border-slate-600 flex items-center justify-center relative bg-slate-50 dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 transition">
                        <img src="{{ $me->profile_photo_url }}" class="w-full h-full rounded-full object-cover p-0.5 opacity-50">
                        <div class="absolute inset-0 flex items-center justify-center">
                            <svg class="w-6 h-6 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M12 4v16m8-8H4"/></svg>
                        </div>
                    </div>
                    <span class="text-[10px] font-semibold text-slate-500 dark:text-gray-400 mt-2">Buat Story</span>
                </div>

                @if(isset($storiesRaw) && !$storiesRaw->isEmpty())
                    @foreach($storiesRaw as $userId => $userStories)
                        @php $storyUser = $userStories->first()->user; @endphp
                        <div class="flex flex-col items-center flex-shrink-0 cursor-pointer hover:opacity-80 transition" onclick="viewStories({{ json_encode($userStories) }})">
                            <div class="w-16 h-16 rounded-full p-0.5 bg-gradient-to-tr from-pink-500 to-indigo-500">
                                <img src="{{ $storyUser->profile_photo_url }}" class="w-full h-full rounded-full object-cover border-2 border-white dark:border-slate-900">
                            </div>
                            <span class="text-[10px] font-semibold text-slate-700 dark:text-gray-300 mt-2 truncate w-16 text-center">{{ $storyUser->id === $me->id ? 'Anda' : explode(' ', $storyUser->name)[0] }}</span>
                        </div>
                    @endforeach
                @endif
            </div>

            <!-- Feed Section -->
            @if(isset($isFeedRecommended) && $isFeedRecommended)
                <div class="mb-6 pb-4 border-b border-slate-200 dark:border-slate-800">
                    <h2 class="text-sm font-bold text-slate-500 dark:text-gray-400 uppercase tracking-wider">Disarankan untuk Anda</h2>
                    <p class="text-xs text-slate-400 dark:text-gray-500 mt-1">Ikuti lebih banyak kreator untuk melihat karya terbaru mereka di beranda Anda.</p>
                </div>
            @endif

            <div class="space-y-8 pb-8">
                @if(isset($feedPhotos))
                    @forelse($feedPhotos as $photo)
                        @php 
                            $ownsPhoto = Auth::check() && $photo->user_id === Auth::id();
                            $purchased = Auth::check() && Auth::user()->hasPurchased($photo->id);
                            $isForSale = $photo->is_for_sale && $photo->price > 0;
                            $needsWatermark = $isForSale && !$ownsPhoto && !$purchased;
                        @endphp
                        <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-[2rem] overflow-hidden shadow-sm max-w-xl mx-auto">
                            <!-- Post Header -->
                            <div class="flex items-center justify-between p-4">
                                <a href="{{ route('profile', $photo->photographer->username ?? $photo->photographer->id) }}" class="flex items-center gap-3 group">
                                    <img src="{{ $photo->photographer->profile_photo_url }}" class="w-10 h-10 rounded-full object-cover ring-2 ring-slate-100 dark:ring-slate-800 group-hover:ring-indigo-500 transition">
                                    <div>
                                        <h4 class="text-sm font-bold text-slate-900 dark:text-white group-hover:text-indigo-500 transition">{{ $photo->photographer->name }}</h4>
                                        <p class="text-[10px] text-slate-500 dark:text-gray-400">{{ $photo->created_at->diffForHumans() }}</p>
                                    </div>
                                </a>
                                <button class="text-slate-400 hover:text-slate-600 dark:hover:text-gray-200 transition">
                                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h.01M12 12h.01M19 12h.01M6 12a1 1 0 11-2 0 1 1 0 012 0zm7 0a1 1 0 11-2 0 1 1 0 012 0zm7 0a1 1 0 11-2 0 1 1 0 012 0z"/></svg>
                                </button>
                            </div>
                            
                            <!-- Post Image -->
                            <div class="relative bg-slate-950/5 dark:bg-slate-950">
                                <img src="{{ asset('storage/' . ($photo->watermarked_path ?? '')) }}" class="w-full h-auto max-h-[600px] object-contain" @if($needsWatermark) draggable="false" oncontextmenu="return false;" @endif>
                                @if($needsWatermark)
                                    <div class="absolute inset-0 pointer-events-none" style="background-image: repeating-linear-gradient(-45deg, transparent, transparent 100px, rgba(255,255,255,0.08) 100px, rgba(255,255,255,0.08) 101px);"></div>
                                @endif
                                @if($isForSale)
                                    <div class="absolute top-4 right-4 bg-black/60 backdrop-blur-md px-3 py-1.5 rounded-full text-xs font-bold text-white shadow-lg border border-white/10">
                                        Rp {{ number_format($photo->price, 0, ',', '.') }}
                                    </div>
                                @endif
                            </div>

                            <!-- Post Actions -->
                            <div class="p-4">
                                <div class="flex items-center justify-between mb-4">
                                    <div class="flex items-center gap-4">
                                        <button class="text-slate-500 dark:text-gray-400 hover:text-pink-500 dark:hover:text-pink-500 transition">
                                            <svg class="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"/></svg>
                                        </button>
                                        <a href="{{ route('photo.show', $photo->id) }}" class="text-slate-500 dark:text-gray-400 hover:text-indigo-500 dark:hover:text-indigo-400 transition">
                                            <svg class="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/></svg>
                                        </a>
                                    </div>
                                    @if(!$ownsPhoto && !$purchased && $isForSale)
                                    <form action="{{ route('cart.add', $photo->id) }}" method="POST">
                                        @csrf
                                        <button type="submit" class="text-slate-500 dark:text-gray-400 hover:text-indigo-500 transition p-1" title="Tambah ke Keranjang">
                                            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"/></svg>
                                        </button>
                                    </form>
                                    @endif
                                </div>

                                <div class="mb-2">
                                    <span class="font-bold text-sm text-slate-900 dark:text-white mr-2">{{ $photo->photographer->name }}</span>
                                    <span class="text-sm text-slate-700 dark:text-gray-300">{{ $photo->title }}</span>
                                </div>
                                @if($photo->description)
                                    <p class="text-xs text-slate-500 dark:text-gray-400 mb-3 line-clamp-2">{{ $photo->description }}</p>
                                @endif
                                @if($photo->likes_count > 0)
                                    <div class="text-xs font-bold text-slate-900 dark:text-white mb-2">{{ $photo->likes_count }} suka</div>
                                @endif
                                <a href="{{ route('photo.show', $photo->id) }}" class="text-xs text-slate-400 dark:text-gray-500 hover:text-slate-600 dark:hover:text-gray-300 font-semibold transition">Lihat semua komentar...</a>
                            </div>
                        </div>
                    @empty
                        <div class="text-center py-12">
                            <div class="w-16 h-16 bg-slate-100 dark:bg-slate-800 rounded-full flex items-center justify-center mx-auto mb-4">
                                <svg class="w-8 h-8 text-slate-400 dark:text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>
                            </div>
                            <p class="text-slate-500 dark:text-gray-400 font-medium">Belum ada kiriman dari kreator yang Anda ikuti.</p>
                            <a href="{{ route('explore') }}" class="mt-4 inline-block px-6 py-2 bg-indigo-50 dark:bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 font-bold rounded-xl hover:bg-indigo-100 dark:hover:bg-indigo-500/20 transition">Eksplorasi Sekarang</a>
                        </div>
                    @endforelse
                @endif
            </div>
        </div>

        <!-- RIGHT COLUMN: USER PROFILE & RECOMMENDATIONS (1/3 width) -->
        <div class="hidden lg:block lg:col-span-1 space-y-6">
            <!-- Mini Profile -->
            <div class="flex items-center gap-4 mt-2">
                <a href="{{ route('profile') }}">
                    <img src="{{ $me->profile_photo_url }}" class="w-14 h-14 rounded-full object-cover ring-2 ring-slate-200 dark:ring-slate-700 hover:ring-indigo-500 transition">
                </a>
                <div class="flex-1">
                    <a href="{{ route('profile') }}" class="font-bold text-sm text-slate-900 dark:text-white hover:underline block">{{ $me->username ?? $me->name }}</a>
                    <span class="text-xs text-slate-500 dark:text-gray-400 block">{{ $me->name }}</span>
                </div>
                <a href="{{ route('logout') }}" onclick="event.preventDefault(); document.getElementById('logout-form').submit();" class="text-xs font-bold text-indigo-500 hover:text-indigo-600 dark:text-indigo-400 transition">Keluar</a>
            </div>

            <!-- Wallet Mini -->
            <div class="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-4 shadow-sm relative overflow-hidden">
                <div class="flex items-center justify-between mb-3 relative z-10">
                    <span class="text-[10px] font-bold text-slate-400 dark:text-gray-500 uppercase tracking-wider">Dompet Anda</span>
                    <a href="{{ route('payment.topup') }}" class="text-xs font-bold text-emerald-500 hover:text-emerald-600 dark:text-emerald-400 transition">Top Up</a>
                </div>
                <p class="text-2xl font-black text-slate-900 dark:text-emerald-400 relative z-10">Rp {{ number_format($me->balance, 0, ',', '.') }}</p>
            </div>

            <!-- Suggested -->
            @if(isset($suggestedPhotographers) && !$suggestedPhotographers->isEmpty())
            <div class="pt-2">
                <div class="flex items-center justify-between mb-4">
                    <h3 class="text-sm font-bold text-slate-500 dark:text-gray-400">Disarankan untuk Anda</h3>
                    <a href="{{ route('explore') }}" class="text-xs font-semibold text-slate-900 dark:text-white hover:text-indigo-500 transition">Lihat Semua</a>
                </div>
                
                <div class="space-y-4">
                    @foreach($suggestedPhotographers as $photographer)
                        <div class="flex items-center justify-between gap-3">
                            <a href="{{ route('profile', $photographer->username ?? $photographer->id) }}" class="flex items-center gap-3 flex-1 min-w-0 group">
                                <img src="{{ $photographer->profile_photo_url }}" class="w-10 h-10 rounded-full object-cover ring-1 ring-slate-200 dark:ring-slate-700 group-hover:ring-indigo-500 transition">
                                <div class="min-w-0">
                                    <h4 class="text-sm font-bold text-slate-900 dark:text-gray-200 truncate group-hover:text-indigo-500 transition">{{ $photographer->username ?? $photographer->name }}</h4>
                                    <p class="text-[10px] text-slate-500 dark:text-gray-500 truncate">{{ $photographer->followers_count }} pengikut</p>
                                </div>
                            </a>
                            <button onclick="toggleFollowSuggested(this, {{ $photographer->id }})" class="text-xs font-bold text-indigo-500 hover:text-indigo-700 dark:text-indigo-400 dark:hover:text-indigo-300 transition">Ikuti</button>
                        </div>
                    @endforeach
                </div>
            </div>
            @endif

            <!-- Footer Links -->
            <div class="text-[10px] text-slate-400 dark:text-slate-600 pt-6 space-y-3">
                <div class="flex flex-wrap gap-x-3 gap-y-1">
                    <a href="#" class="hover:underline">Tentang</a>
                    <a href="#" class="hover:underline">Bantuan</a>
                    <a href="#" class="hover:underline">Privasi</a>
                    <a href="#" class="hover:underline">Ketentuan</a>
                    <a href="#" class="hover:underline">Lokasi</a>
                </div>
                <p>&copy; {{ date('Y') }} KREAVANA DARI NABIL EFRIANSYAH</p>
            </div>
        </div>
        
    </div>
</div>

@section('scripts')
<script>
    // AJAX Follow Toggle from Suggested list
    function toggleFollowSuggested(button, userId) {
        const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
        
        button.disabled = true;
        button.innerText = '...';
        
        fetch(`/user/follow/${userId}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-TOKEN': token,
                'Accept': 'application/json'
            }
        })
        .then(response => {
            if (response.status === 401) {
                window.location.href = "{{ route('login') }}";
                return;
            }
            return response.json();
        })
        .then(data => {
            button.disabled = false;
            if (data && data.success) {
                if (data.following) {
                    button.innerText = 'Mengikuti';
                    button.className = "text-xs font-bold text-slate-500 hover:text-slate-700 dark:text-gray-400 dark:hover:text-gray-300 transition";
                } else {
                    button.innerText = 'Ikuti';
                    button.className = "text-xs font-bold text-indigo-500 hover:text-indigo-700 dark:text-indigo-400 dark:hover:text-indigo-300 transition";
                }
            }
        })
        .catch(err => {
            button.disabled = false;
            button.innerText = 'Ikuti';
            console.error('Error following:', err);
        });
    }
</script>
@endsection
@endsection
