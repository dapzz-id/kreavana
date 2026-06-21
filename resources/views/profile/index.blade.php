@extends('layouts.app')
@section('title', $user->name . ' (@' . ($user->username ?? $user->id) . ') - KREAVANA')

@section('styles')
<style>
    [x-cloak]{display:none!important}
    .ig-grid-item{position:relative;cursor:pointer;background:#1e293b;overflow:hidden;}
    .ig-grid-item img{width:100%;height:100%;object-fit:cover;transition:transform .3s}
    .ig-grid-item:hover img{transform:scale(1.05)}
    .ig-overlay{position:absolute;inset:0;background:rgba(0,0,0,.5);opacity:0;display:flex;align-items:center;justify-content:center;gap:1.5rem;color:#fff;font-weight:700;transition:opacity .2s;pointer-events:none}
    .ig-grid-item:hover .ig-overlay{opacity:1;pointer-events:auto}
</style>
@endsection

@section('content')
@php 
    $me = Auth::user(); 
    $isOwnProfile = $me && $me->id === $user->id;
@endphp

<div class="max-w-5xl mx-auto px-4 py-6" x-data="{ tab: '{{ $user->isPhotographer() ? 'posts' : ($isOwnProfile ? 'purchased' : 'posts') }}', searchQuery: '' }">

    <!-- ─── PROFILE HEADER ─────────────────────────────────────────────────── -->
    <div class="flex flex-col md:flex-row items-center md:items-start gap-6 md:gap-14 mb-10 mt-6">

        <!-- Avatar -->
        <div class="shrink-0">
            <div class="w-28 h-28 md:w-36 md:h-36 rounded-full p-[3px] bg-gradient-to-tr from-yellow-400 via-pink-500 to-indigo-500 shadow-2xl shadow-pink-500/20">
                <img src="{{ $user->profile_photo_url }}"
                     class="w-full h-full object-cover rounded-full border-4 border-slate-900"
                     alt="{{ $user->name }}">
            </div>
        </div>

        <!-- Info -->
        <div class="flex-grow text-center md:text-left space-y-4 max-w-xl">
            <div class="flex flex-wrap items-center gap-3 justify-center md:justify-start">
                <h2 class="text-xl font-semibold text-gray-100">{{ $user->name }}</h2>
                @if($user->username)<span class="text-gray-500 text-sm">{{ '@' . $user->username }}</span>@endif
                
                @if($isOwnProfile)
                    <a href="{{ route('profile.edit') }}" class="px-4 py-1.5 bg-slate-800 hover:bg-slate-700 border border-slate-700 rounded-lg text-xs font-bold text-gray-200 transition">Edit Profil</a>
                    <a href="{{ route('profile.edit') }}#face" class="px-4 py-1.5 bg-indigo-600/20 hover:bg-indigo-600/40 border border-indigo-500/30 rounded-lg text-xs font-bold text-indigo-300 transition flex items-center gap-1.5">
                        <span class="w-2 h-2 rounded-full bg-indigo-400 animate-pulse"></span>
                        RoboYu Scan
                    </a>
                @elseif(Auth::check())
                    <button onclick="toggleFollowProfile(this, {{ $user->id }})" 
                            class="px-5 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 {{ $isFollowing ? 'bg-slate-800 hover:bg-slate-700 text-gray-300 border border-slate-700' : 'bg-indigo-600 hover:bg-indigo-500 text-white' }}">
                        {{ $isFollowing ? 'Mengikuti' : 'Ikuti' }}
                    </button>
                    @if(!$user->isUser())
                        <a href="{{ route('messages.show', $user->id) }}" class="px-4 py-1.5 bg-slate-800 hover:bg-slate-700 border border-slate-700 rounded-lg text-xs font-bold text-gray-200 transition">Pesan</a>
                    @endif
                @endif
            </div>

            <!-- Stats -->
            <div class="flex justify-center md:justify-start gap-8">
                <div class="text-center md:text-left">
                    <span class="font-bold text-white block text-lg" id="profile-posts-count">{{ $stats['posts'] }}</span>
                    <span class="text-xs text-gray-400">kiriman</span>
                </div>
                <div class="text-center md:text-left">
                    <span class="font-bold text-white block text-lg" id="profile-followers-count">{{ $stats['followers'] }}</span>
                    <span class="text-xs text-gray-400">pengikut</span>
                </div>
                <div class="text-center md:text-left">
                    <span class="font-bold text-white block text-lg">{{ $stats['following'] }}</span>
                    <span class="text-xs text-gray-400">diikuti</span>
                </div>
                @if($isOwnProfile)
                <div class="text-center md:text-left">
                    <span class="font-bold text-emerald-400 block text-lg">{{ $stats['purchased'] }}</span>
                    <span class="text-xs text-gray-400">dibeli</span>
                </div>
                @endif
            </div>

            <!-- Bio -->
            @if($user->bio)
            <p class="text-sm text-gray-300 leading-relaxed">{{ $user->bio }}</p>
            @endif
            @if($user->website)
            <a href="{{ $user->website }}" target="_blank" class="text-sm text-indigo-400 hover:underline flex items-center gap-1 justify-center md:justify-start">
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/></svg>
                {{ parse_url($user->website, PHP_URL_HOST) }}
            </a>
            @endif
            
            <!-- Balance (Only for own profile) -->
            @if($isOwnProfile)
            <p class="text-sm text-gray-400">
                Saldo: <a href="{{ route('payment.topup') }}" class="font-bold text-indigo-400 hover:underline">Rp {{ number_format($me->balance, 0, ',', '.') }}</a>
            </p>
            @endif
        </div>
    </div>

    <!-- ─── SEARCH ─────────────────────────────────────────────────────────── -->
    @if($user->isPhotographer() || $isOwnProfile)
    <div class="mb-5 max-w-sm mx-auto">
        <div class="relative">
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <svg class="h-4 w-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>
            </div>
            <input x-model="searchQuery" type="text"
                   class="w-full pl-9 pr-4 py-2 bg-slate-800 border border-slate-700 rounded-lg text-gray-200 placeholder-gray-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 transition text-sm"
                   placeholder="Cari foto di profil...">
        </div>
    </div>
    @endif

    <!-- ─── TABS ───────────────────────────────────────────────────────────── -->
    <div class="border-t border-slate-800">
        <div class="flex justify-center gap-8 md:gap-14">
            @if($user->isPhotographer())
            <button @click="tab='posts'" :class="tab==='posts'?'border-t-2 border-white text-white':'text-gray-500 hover:text-gray-300'"
                    class="py-4 text-[11px] font-bold uppercase tracking-widest flex items-center gap-1.5 transition -mt-px">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7" rx="1" stroke-width="2"/><rect x="14" y="3" width="7" height="7" rx="1" stroke-width="2"/><rect x="3" y="14" width="7" height="7" rx="1" stroke-width="2"/><rect x="14" y="14" width="7" height="7" rx="1" stroke-width="2"/></svg>
                <span class="hidden md:inline">Kiriman</span>
            </button>
            @endif
            
            @if($isOwnProfile)
            @if(!$user->isPhotographer())
            <button onclick="document.getElementById('creator-request-modal').classList.remove('hidden')"
                    class="py-4 text-[11px] font-bold uppercase tracking-widest flex items-center gap-1.5 transition -mt-px text-emerald-400 hover:text-emerald-300 border-t-2 border-transparent">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"/></svg>
                <span class="hidden md:inline">Jadi Kreator</span>
            </button>
            @endif
            <button @click="tab='purchased'" :class="tab==='purchased'?'border-t-2 border-white text-white':'text-gray-500 hover:text-gray-300 border-t-2 border-transparent'"
                    class="py-4 text-[11px] font-bold uppercase tracking-widest flex items-center gap-1.5 transition -mt-px">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/></svg>
                <span class="hidden md:inline">Dibeli</span>
            </button>
            <button @click="tab='saved'" :class="tab==='saved'?'border-t-2 border-white text-white':'text-gray-500 hover:text-gray-300'"
                    class="py-4 text-[11px] font-bold uppercase tracking-widest flex items-center gap-1.5 transition -mt-px">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"/></svg>
                <span class="hidden md:inline">Disimpan</span>
            </button>
            <button @click="tab='tagged'" :class="tab==='tagged'?'border-t-2 border-white text-white':'text-gray-500 hover:text-gray-300'"
                    class="py-4 text-[11px] font-bold uppercase tracking-widest flex items-center gap-1.5 transition -mt-px">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/></svg>
                <span class="hidden md:inline">Tag & Wajah</span>
            </button>
            @endif
        </div>
    </div>

    <!-- ─── TAB CONTENT ────────────────────────────────────────────────────── -->
    <div class="mt-1 min-h-[40vh]">

        @if($user->isPhotographer())
        {{-- POSTS TAB --}}
        <div x-show="tab==='posts'" x-cloak>
            @if($uploadedPhotos->isEmpty())
                <div class="flex flex-col items-center justify-center py-20 text-center">
                    <svg class="w-12 h-12 text-slate-600 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                    <h3 class="text-sm font-bold text-slate-400">Belum Ada Kiriman</h3>
                    <p class="text-xs text-slate-500 mt-1">Fotografer belum membagikan karya foto apapun.</p>
                </div>
            @else
                <div class="grid grid-cols-3 gap-0.5 md:gap-1">
                    @foreach($uploadedPhotos as $photo)
                    <div class="aspect-square ig-grid-item" x-show="searchQuery===''||'{{ strtolower($photo->title ?? '') }}'.includes(searchQuery.toLowerCase())">
                        <img src="{{ asset('storage/'.$photo->watermarked_path) }}" alt="{{ $photo->title }}">
                        <a href="{{ route('photo.show', $photo->id) }}" class="ig-overlay">
                            <div class="flex items-center gap-1"><svg class="w-4 h-4 fill-white" viewBox="0 0 24 24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>{{ $photo->likes_count ?? 0 }}</div>
                            <div class="flex items-center gap-1"><svg class="w-4 h-4 fill-white" viewBox="0 0 24 24"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/></svg>{{ $photo->comments()->count() }}</div>
                        </a>
                    </div>
                    @endforeach
                </div>
            @endif
        </div>
        @elseif(!$isOwnProfile)
            {{-- Non-photographer viewed profile empty state --}}
            <div class="text-center py-20">
                <svg class="w-12 h-12 text-slate-650 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
                <h3 class="text-sm font-bold text-slate-400">Profil Pengguna</h3>
                <p class="text-xs text-slate-500 mt-1">Pengguna ini terdaftar sebagai kolektor/klien.</p>
            </div>
        @endif

        @if($isOwnProfile)
        {{-- PURCHASED TAB --}}
        <div x-show="tab==='purchased'" x-cloak>
            @if($purchasedPhotos->isEmpty())
                @include('dashboard._empty_state', ['icon' => 'bag', 'title' => 'Belum Ada Pembelian', 'subtitle' => 'Foto asli yang Anda beli akan muncul di sini.', 'action_url' => route('explore'), 'action_label' => 'Mulai Belanja'])
            @else
                <div class="grid grid-cols-3 gap-0.5 md:gap-1">
                    @foreach($purchasedPhotos as $photo)
                    <div class="aspect-square ig-grid-item group relative" x-show="searchQuery===''||'{{ strtolower($photo->title??'') }}'.includes(searchQuery.toLowerCase())">
                        <img src="{{ asset('storage/'.$photo->watermarked_path) }}" alt="{{ $photo->title }}">
                        <div class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 flex flex-col items-center justify-center gap-2 transition-opacity">
                            <a href="{{ route('photo.download', $photo->id) }}" class="p-2.5 bg-white text-gray-900 rounded-full hover:scale-110 transition">
                                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/></svg>
                            </a>
                            <span class="text-[10px] font-bold text-white uppercase tracking-widest">Unduh Asli</span>
                        </div>
                    </div>
                    @endforeach
                </div>
            @endif
        </div>

        {{-- SAVED TAB --}}
        <div x-show="tab==='saved'" x-cloak>
            @if($savedPhotos->isEmpty())
                @include('dashboard._empty_state', ['icon' => 'bookmark', 'title' => 'Simpan Foto Favorit', 'subtitle' => 'Foto yang Anda simpan dari Explore akan muncul di sini.'])
            @else
                <div class="grid grid-cols-3 gap-0.5 md:gap-1">
                    @foreach($savedPhotos as $photo)
                    <div class="aspect-square ig-grid-item" x-show="searchQuery===''||'{{ strtolower($photo->title??'') }}'.includes(searchQuery.toLowerCase())">
                        <img src="{{ asset('storage/'.$photo->watermarked_path) }}" alt="{{ $photo->title }}">
                        <a href="{{ route('photo.show', $photo->id) }}" class="ig-overlay"><span class="uppercase tracking-wider text-xs">Lihat Detail</span></a>
                    </div>
                    @endforeach
                </div>
            @endif
        </div>

        {{-- TAGGED / ROBOYU TAB --}}
        <div x-show="tab==='tagged'" x-cloak class="py-16 text-center">
            <div class="w-16 h-16 mx-auto mb-4 rounded-full border-2 border-indigo-500/50 flex items-center justify-center shadow-[0_0_20px_rgba(99,102,241,0.3)]">
                <svg class="w-8 h-8 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/></svg>
            </div>
            <h3 class="text-xl font-bold text-gray-300">
                @if($user->face_embeddings)
                    Mencari foto Anda di galeri...
                @else
                    Daftarkan Wajah Anda
                @endif
            </h3>
            <p class="text-sm text-gray-500 mt-2 max-w-xs mx-auto">
                @if($user->face_embeddings)
                    Sistem AI RoboYu sedang memproses. Foto yang cocok akan muncul di sini.
                @else
                    Unggah selfie di pengaturan profil untuk mengaktifkan pencarian foto otomatis berbasis AI.
                @endif
            </p>
            <a href="{{ route('profile.edit') }}" class="mt-5 inline-flex items-center gap-2 px-6 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-sm font-bold transition">
                @if($user->face_embeddings) Perbarui Selfie @else Daftarkan Wajah @endif
            </a>
        </div>
        @endif

    </div>
</div>

<!-- ─── CREATOR REQUEST MODAL ───────────────────────────────────────────── -->
@if($isOwnProfile && !$user->isPhotographer())
<div id="creator-request-modal" class="hidden fixed inset-0 z-[100] bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
    <div class="bg-slate-900 border border-slate-700 rounded-3xl w-full max-w-md shadow-2xl overflow-hidden">
        <div class="flex items-center justify-between px-6 py-4 border-b border-slate-800">
            <h3 class="font-bold text-white">Daftar Jadi Kreator</h3>
            <button onclick="document.getElementById('creator-request-modal').classList.add('hidden')" class="text-gray-400 hover:text-white transition">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
        </div>
        
        @if(isset($photographerRequest) && $photographerRequest && $photographerRequest->status === 'pending')
        <div class="p-6 text-center">
            <div class="w-16 h-16 mx-auto mb-4 bg-amber-500/20 rounded-full flex items-center justify-center">
                <svg class="w-8 h-8 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
            </div>
            <h4 class="text-lg font-bold text-gray-200 mb-2">Permintaan Sedang Diproses</h4>
            <p class="text-sm text-gray-400">Tim kami sedang meninjau dokumen KTP dan NPWP Anda. Mohon tunggu informasi selanjutnya.</p>
            <button onclick="document.getElementById('creator-request-modal').classList.add('hidden')" class="mt-6 w-full py-2.5 bg-slate-800 hover:bg-slate-700 text-white rounded-xl transition">Tutup</button>
        </div>
        @else
        <form action="{{ route('profile.request_photographer') }}" method="POST" enctype="multipart/form-data" class="p-6 space-y-5">
            @csrf
            <div>
                <p class="text-sm text-gray-400 mb-4">Unggah dokumen identitas Anda (Foto/Scan) untuk diverifikasi sebagai kreator.</p>
            </div>
            
            <div>
                <label class="block text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Unggah KTP (Foto/PDF)</label>
                <input type="file" name="ktp" accept=".jpg,.jpeg,.png,.pdf" required
                       class="w-full px-4 py-2 bg-slate-800 border border-slate-700 rounded-xl text-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500">
            </div>

            <div>
                <label class="block text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">Unggah NPWP (Foto/PDF)</label>
                <input type="file" name="npwp" accept=".jpg,.jpeg,.png,.pdf" required
                       class="w-full px-4 py-2 bg-slate-800 border border-slate-700 rounded-xl text-gray-200 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500">
            </div>

            <button type="submit" class="w-full py-3 mt-2 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-xl transition shadow-lg">
                Kirim Permintaan
            </button>
        </form>
        @endif
    </div>
</div>
@endif

@section('scripts')
<script>
    function toggleFollowProfile(button, userId) {
        const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
        
        button.disabled = true;
        button.innerText = 'Memproses...';
        
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
                const followerSpan = document.getElementById('profile-followers-count');
                
                if (data.following) {
                    button.innerText = 'Mengikuti';
                    button.className = "px-5 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 bg-slate-800 hover:bg-slate-700 text-gray-300 border border-slate-700";
                } else {
                    button.innerText = 'Ikuti';
                    button.className = "px-5 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 bg-indigo-600 hover:bg-indigo-500 text-white";
                }
                
                if (followerSpan) {
                    followerSpan.innerText = data.followers_count;
                }
            } else {
                button.innerText = 'Gagal';
            }
        })
        .catch(err => {
            button.disabled = false;
            button.innerText = 'Gagal';
            console.error('Error follow:', err);
        });
    }
</script>
@endsection
@endsection
