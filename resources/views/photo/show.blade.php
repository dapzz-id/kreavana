@extends('layouts.app')
@section('title', $photo->title . ' - KREAVANA')

@section('styles')
<style>
    .wm-overlay {
        background-image:
            repeating-linear-gradient(
                -45deg,
                transparent,
                transparent 80px,
                rgba(255,255,255,0.06) 80px,
                rgba(255,255,255,0.06) 81px
            );
        z-index: 2;
    }
    .wm-overlay::before {
        content: 'kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana   kreavana';
        position: absolute;
        inset: -50%;
        display: flex;
        flex-wrap: wrap;
        align-content: center;
        justify-content: center;
        font-size: 16px;
        font-weight: 700;
        letter-spacing: 8px;
        line-height: 3;
        color: rgba(255, 255, 255, 0.12);
        text-transform: uppercase;
        transform: rotate(-35deg);
        pointer-events: none;
        user-select: none;
        word-spacing: 40px;
        overflow: hidden;
    }
</style>
@endsection

@section('content')
<div class="max-w-5xl mx-auto py-4">
    <!-- Back Button -->
    <a href="{{ route('explore') }}" class="inline-flex items-center gap-2 text-sm text-gray-400 hover:text-white mb-6 transition">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path></svg>
        Kembali ke Galeri
    </a>

    <!-- Detail Card -->
    <div class="glass rounded-2xl border border-gray-900 overflow-hidden shadow-2xl grid grid-cols-1 lg:grid-cols-12">
        
        <!-- Left: Image Preview (Col 7) -->
        <div class="lg:col-span-7 bg-gray-950 flex items-center justify-center relative min-h-[350px] lg:min-h-[500px] overflow-hidden">
            <img src="{{ asset('storage/' . $photo->watermarked_path) }}" 
                 alt="{{ $photo->title }}" 
                 class="max-w-full max-h-[600px] object-contain"
                 @if($photo->is_for_sale && !$hasPurchased) draggable="false" oncontextmenu="return false;" @endif>
            
            @if($photo->is_for_sale && !$hasPurchased)
                <div class="absolute inset-0 pointer-events-none select-none wm-overlay" aria-hidden="true"></div>
                <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
                    <span class="px-4 py-2 rounded-lg bg-black/60 border border-white/10 text-white/80 text-xs font-bold uppercase tracking-widest">
                        Preview &bull; Beli untuk versi asli
                    </span>
                </div>
            @endif
        </div>

        <!-- Right: Information & Socials (Col 5) -->
        <div class="lg:col-span-5 flex flex-col justify-between border-t lg:border-t-0 lg:border-l border-gray-900/60 h-full">
            
            <!-- Side Header (Photographer info) -->
            <div class="p-5 border-b border-gray-900/60 flex items-center justify-between">
                <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-full bg-gradient-to-tr from-indigo-500 to-pink-500 flex items-center justify-center font-bold text-white uppercase text-sm">
                        {{ substr($photo->photographer->name, 0, 2) }}
                    </div>
                    <div>
                        <h4 class="text-sm font-bold text-gray-200">{{ $photo->photographer->name }}</h4>
                        <p class="text-xs text-indigo-400 font-medium">Photographer</p>
                    </div>
                </div>

                @if($photo->is_for_sale)
                    <div class="text-right">
                        <p class="text-xs text-gray-500 uppercase tracking-wider font-semibold">Harga</p>
                        <p class="text-base font-bold text-indigo-400">Rp {{ number_format($photo->price, 0, ',', '.') }}</p>
                    </div>
                @else
                    <div class="text-right">
                        <span class="px-2.5 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-xs font-bold">Gratis</span>
                    </div>
                @endif
            </div>

            <!-- Content Area -->
            <div class="p-5 flex-grow overflow-y-auto space-y-4">
                <div>
                    <h1 class="text-xl font-bold text-gray-100">{{ $photo->title }}</h1>
                    <p class="text-xs text-gray-400 mt-2 leading-relaxed">{{ $photo->description }}</p>
                </div>

                @if($photo->tags)
                    <div class="flex flex-wrap gap-1.5 pt-2">
                        @foreach(explode(',', $photo->tags) as $tag)
                            <span class="px-2 py-0.5 rounded bg-gray-900 border border-gray-800 text-[10px] text-gray-400 font-semibold hover:border-indigo-500/30 transition cursor-pointer">
                                #{{ trim($tag) }}
                            </span>
                        @endforeach
                    </div>
                @endif

                <!-- Purchases & Download Actions Card -->
                <div class="p-4 rounded-xl border border-gray-800 bg-gray-950/40 mt-4">
                    @auth
                        @php $ownsPhoto = $photo->user_id === Auth::id(); @endphp
                        
                        @if($photo->is_free)
                            <div class="text-center">
                                <p class="text-xs text-gray-400 mb-3">Foto ini tidak berbayar. Anda dapat mengunduh berkas asli beresolusi penuh secara langsung.</p>
                                <a href="{{ route('photo.download', $photo->id) }}" class="w-full py-2.5 px-4 rounded-xl text-xs font-bold text-center block bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-white shadow shadow-emerald-500/20 transition-all">
                                    Unduh File Asli (Gratis)
                                </a>
                            </div>
                        @elseif($ownsPhoto)
                            <div class="text-center py-1">
                                <span class="px-3 py-1 rounded bg-gray-900 border border-gray-800 text-gray-400 text-xs font-bold">Ini adalah karya Anda sendiri</span>
                            </div>
                        @elseif($hasPurchased)
                            <div class="text-center">
                                <div class="flex items-center justify-center gap-2 mb-3">
                                    <svg class="w-5 h-5 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                                    <span class="text-xs font-bold text-emerald-400">Pembelian Terverifikasi</span>
                                </div>
                                <a href="{{ route('photo.download', $photo->id) }}" class="w-full py-2.5 px-4 rounded-xl text-xs font-bold text-center block bg-gradient-to-r from-indigo-500 via-purple-500 to-pink-500 hover:from-indigo-400 hover:to-pink-400 text-white shadow shadow-indigo-500/20 transition-all">
                                    Unduh Resolusi Asli (Tanpa Watermark)
                                </a>
                            </div>
                        @else
                            <div class="text-center">
                                <p class="text-xs text-gray-400 mb-3">Beli foto ini untuk mengunduh resolusi asli beresolusi penuh tanpa watermark.</p>
                                <form action="{{ route('cart.add', $photo->id) }}" method="POST">
                                    @csrf
                                    <button type="submit" class="w-full py-2.5 px-4 rounded-xl text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white shadow shadow-indigo-500/20 transition-all flex items-center justify-center gap-1.5">
                                        <svg class="w-4.5 h-4.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"></path></svg>
                                        Tambahkan ke Keranjang
                                    </button>
                                </form>
                            </div>
                        @endif
                    @else
                        <div class="text-center">
                            @if($photo->is_free)
                                <a href="{{ route('login') }}" class="w-full py-2.5 px-4 rounded-xl text-xs font-bold text-center block bg-gray-850 hover:bg-gray-800 border border-gray-800 text-gray-300 transition-all">
                                    Masuk untuk Mengunduh Gratis
                                </a>
                            @else
                                <a href="{{ route('login') }}" class="w-full py-2.5 px-4 rounded-xl text-xs font-bold text-center block bg-indigo-600 hover:bg-indigo-500 text-white shadow shadow-indigo-500/20 transition-all">
                                    Masuk untuk Melakukan Pembelian
                                </a>
                            @endif
                        </div>
                    @endauth
                </div>

                <!-- Comments Section -->
                <div class="pt-4 border-t border-gray-900/60" id="comments-section">
                    <h5 class="text-xs font-extrabold uppercase tracking-wider text-gray-400 mb-3">Komentar ({{ $photo->comments->count() }})</h5>
                    
                    @if($photo->comments->isEmpty())
                        <p class="text-xs text-gray-600 italic">Belum ada komentar untuk foto ini.</p>
                    @else
                        <div class="space-y-3.5 max-h-[160px] overflow-y-auto pr-2">
                            @foreach($photo->comments as $comment)
                                <div class="flex items-start gap-2.5">
                                    <div class="w-6.5 h-6.5 rounded-full bg-indigo-500/20 flex items-center justify-center text-[10px] font-bold text-indigo-400 uppercase">
                                        {{ substr($comment->user->name, 0, 2) }}
                                    </div>
                                    <div class="flex-1 bg-gray-950/60 p-2.5 rounded-xl border border-gray-900">
                                        <div class="flex justify-between items-center">
                                            <span class="text-[10px] font-bold text-gray-300">{{ $comment->user->name }}</span>
                                            <span class="text-[9px] text-gray-500">{{ $comment->created_at->diffForHumans() }}</span>
                                        </div>
                                        <p class="text-xs text-gray-400 mt-1">{{ $comment->content }}</p>
                                    </div>
                                </div>
                            @endforeach
                        </div>
                    @endif
                </div>
            </div>

            <!-- Side Footer (Interaction Buttons & Comment Input) -->
            <div class="p-4 border-t border-gray-900/60 bg-gray-950/60 space-y-3">
                <div class="flex items-center justify-between">
                    <div class="flex items-center gap-3">
                        <!-- Like Button -->
                        <button type="button" onclick="toggleLikeInShow(this)" class="flex items-center gap-1.5 text-gray-400 hover:text-red-500 transition">
                            <svg class="w-5.5 h-5.5 {{ $hasLiked ? 'fill-red-500 text-red-500' : 'text-gray-400' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"></path>
                            </svg>
                            <span id="likes-count-show" class="text-xs font-bold">{{ $photo->likes_count }}</span>
                        </button>
                        
                        <!-- Share button -->
                        <button type="button" onclick="copyLinkShow()" class="text-gray-400 hover:text-indigo-400 transition" title="Salin Tautan">
                            <svg class="w-5.5 h-5.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 10.742l4.887-2.443m0 0a3.001 3.001 0 110 5.854l-4.887 2.443m0 0a3.001 3.001 0 11-4.884-2.444l4.884-2.443m0 0a3.001 3.001 0 004.884 2.444z"></path>
                            </svg>
                        </button>
                    </div>

                    <!-- Bookmark -->
                    <button type="button" onclick="toggleSaveInShow(this)" class="text-gray-400 hover:text-indigo-400 transition">
                        <svg class="w-5.5 h-5.5 {{ $hasSaved ? 'fill-indigo-400 text-indigo-400' : 'text-gray-400' }}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"></path>
                        </svg>
                    </button>
                </div>

                <!-- Add Comment Form -->
                @auth
                    <form action="{{ route('photo.comment', $photo->id) }}" method="POST" class="relative">
                        @csrf
                        <input type="text" name="content" required placeholder="Tulis komentar..." class="w-full pl-3 pr-12 py-2.5 bg-gray-900 border border-gray-800 rounded-xl text-xs text-gray-200 focus:outline-none focus:ring-1 focus:ring-indigo-500">
                        <button type="submit" class="absolute right-3.5 top-2.5 text-xs text-indigo-400 hover:text-indigo-300 font-bold transition">Kirim</button>
                    </form>
                @else
                    <p class="text-[10px] text-gray-500 text-center py-1">
                        <a href="{{ route('login') }}" class="text-indigo-400 font-semibold hover:underline">Masuk</a> untuk menyukai dan mengomentari foto ini.
                    </p>
                @endauth
            </div>

        </div>

    </div>
</div>
@endsection

@section('scripts')
<script>
    // AJAX Toggle Like in detail
    function toggleLikeInShow(button) {
        const url = `{{ route('photo.like', $photo->id) }}`;
        const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

        fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-TOKEN': csrfToken,
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
            if (data && data.success) {
                const svg = button.querySelector('svg');
                const countSpan = document.getElementById('likes-count-show');
                
                if (data.liked) {
                    svg.classList.add('fill-red-500', 'text-red-500');
                } else {
                    svg.classList.remove('fill-red-500', 'text-red-500');
                }
                countSpan.innerText = data.likes_count;
            }
        })
        .catch(err => console.error('Error toggling like:', err));
    }

    // AJAX Toggle Save in detail
    function toggleSaveInShow(button) {
        const url = `{{ route('photo.save', $photo->id) }}`;
        const csrfToken = document.querySelector('meta[name="csrf-token"]').content;

        fetch(url, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-TOKEN': csrfToken,
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
            if (data && data.success) {
                const svg = button.querySelector('svg');
                if (data.saved) {
                    svg.classList.add('fill-indigo-400', 'text-indigo-400');
                } else {
                    svg.classList.remove('fill-indigo-400', 'text-indigo-400');
                }
            }
        })
        .catch(err => console.error('Error toggling save:', err));
    }

    // Share link copying
    function copyLinkShow() {
        navigator.clipboard.writeText(window.location.href).then(() => {
            alert('Tautan foto disalin ke papan klip!');
        }).catch(err => {
            console.error('Gagal menyalin tautan:', err);
        });
    }
</script>
@endsection
