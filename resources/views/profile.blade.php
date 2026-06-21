@extends('layouts.dashboard')
@section('title', 'Profil Saya - KREAVANA')

@section('content')
<div class="py-4 space-y-8">
    
    <!-- User Profile Header Card -->
    <div class="glass p-6 md:p-8 rounded-3xl border border-gray-800 shadow-2xl flex flex-col md:flex-row justify-between items-start md:items-center gap-6 relative overflow-hidden bg-gradient-to-br from-gray-900 via-gray-950 to-indigo-950/20">
        <!-- Abstract Decoration -->
        <div class="absolute -top-24 -right-24 w-64 h-64 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none"></div>
        <div class="absolute bottom-0 left-1/4 w-32 h-32 bg-pink-500/10 rounded-full blur-2xl pointer-events-none"></div>
        
        <div class="flex items-center gap-5 relative z-10">
            <div class="w-20 h-20 md:w-24 md:h-24 rounded-full bg-gradient-to-tr from-indigo-500 to-pink-500 flex items-center justify-center font-extrabold text-white text-3xl shadow-lg shadow-indigo-500/20 ring-4 ring-gray-900">
                {{ substr($user->name, 0, 2) }}
            </div>
            <div>
                <h2 class="text-2xl md:text-3xl font-extrabold text-gray-100 tracking-tight">{{ $user->name }}</h2>
                <p class="text-sm text-gray-400 mt-1">{{ $user->email }}</p>
                <div class="flex flex-wrap gap-2 mt-3">
                    <span class="px-3 py-1 rounded-full bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 text-xs font-bold uppercase tracking-wider">
                        {{ $user->role->name }}
                    </span>
                    <span class="px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-xs font-bold flex items-center gap-1">
                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                        Saldo: Rp {{ number_format($user->balance, 0, ',', '.') }}
                    </span>
                </div>
            </div>
        </div>

        <div class="relative z-10 w-full md:w-auto mt-2 md:mt-0">
            <p class="text-[10px] text-gray-500 mb-2 uppercase tracking-wider font-bold md:text-right">Dompet Digital</p>
            <a href="{{ route('payment.topup') }}" class="flex items-center justify-center gap-2 w-full md:w-auto px-6 py-3.5 rounded-xl bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-indigo-400 text-white text-sm font-bold shadow-xl shadow-indigo-500/20 transition-all transform hover:-translate-y-0.5">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"></path></svg>
                Isi Saldo
            </a>
        </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-12 gap-8">
        
        <!-- Left: Photographer Requests Form (Col 4) -->
        <div class="lg:col-span-4">
            @if(!$user->isPhotographer() && !$user->isSuperadmin())
                <div class="glass p-6 rounded-2xl border border-gray-900 shadow-xl space-y-5">
                    <div>
                        <h3 class="text-sm font-bold text-gray-200">Ingin Menjual Karya Foto?</h3>
                        <p class="text-xs text-gray-500 mt-1">Ajukan diri Anda menjadi fotografer resmi KREAVANA dengan melengkapi berkas verifikasi identitas berikut.</p>
                    </div>

                    <!-- Application status checker -->
                    @if($photographerRequest)
                        @if($photographerRequest->status === 'pending')
                            <!-- Pending state -->
                            <div class="p-4 rounded-xl border border-yellow-500/20 bg-yellow-500/5 text-center space-y-2">
                                <span class="px-2 py-0.5 rounded bg-yellow-500/10 border border-yellow-500/20 text-yellow-500 text-[9px] font-extrabold uppercase tracking-wider">Pengajuan Diproses</span>
                                <p class="text-[11px] text-gray-400 leading-relaxed">Berkas KTP dan NPWP Anda sudah kami terima dan sedang diverifikasi oleh admin. Mohon ditunggu.</p>
                            </div>
                        @elseif($photographerRequest->status === 'rejected')
                            <!-- Rejected state (display notes + let them submit again) -->
                            <div class="p-4 rounded-xl border border-red-500/20 bg-red-500/5 space-y-2 mb-2">
                                <div class="text-center">
                                    <span class="px-2 py-0.5 rounded bg-red-500/10 border border-red-500/20 text-red-400 text-[9px] font-extrabold uppercase tracking-wider">Pengajuan Ditolak</span>
                                </div>
                                <p class="text-[11px] text-gray-400 leading-relaxed"><strong>Catatan Admin:</strong> <span class="text-red-300">"{{ $photographerRequest->admin_notes }}"</span></p>
                            </div>
                            
                            <!-- Re-submit form -->
                            @include('partials.photographer_form')
                        @endif
                    @else
                        <!-- No requests, show form -->
                        @include('partials.photographer_form')
                    @endif
                </div>
            @else
                <div class="glass p-6 rounded-2xl border border-gray-900 shadow-xl text-center py-8">
                    <svg class="w-12 h-12 text-emerald-500/20 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path></svg>
                    <h3 class="text-sm font-bold text-gray-200">Status Akun Terverifikasi</h3>
                    <p class="text-xs text-gray-500 mt-1">Akun Anda memiliki akses khusus untuk peran <strong>{{ $user->role->name }}</strong>.</p>
                </div>
            @endif
        </div>

        <!-- Right: Galleries (Col 8) -->
        <div class="lg:col-span-8 space-y-6">
            
            <!-- Tab controllers -->
            <div class="flex border-b border-gray-900 gap-2">
                <button onclick="switchProfileTab('purchased')" id="p-tab-btn-purchased" class="px-4 py-2.5 border-b-2 border-indigo-500 text-xs font-bold text-gray-100 focus:outline-none transition">
                    Foto yang Dibeli ({{ $purchasedPhotos->count() }})
                </button>
                <button onclick="switchProfileTab('saved')" id="p-tab-btn-saved" class="px-4 py-2.5 border-b-2 border-transparent text-xs font-bold text-gray-400 hover:text-gray-200 focus:outline-none transition">
                    Disimpan ({{ $savedPhotos->count() }})
                </button>
            </div>

            <!-- Tab Content -->
            <div class="mt-4">
                <!-- Tab: Purchased Photos -->
                <div id="p-tab-purchased" class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5 animate-fade-in">
                    @if($purchasedPhotos->isEmpty())
                        <div class="col-span-full flex flex-col items-center justify-center py-16 border-2 border-dashed border-gray-800 rounded-3xl bg-gray-900/20">
                            <svg class="w-12 h-12 text-gray-700 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                            <p class="text-sm text-gray-500 font-medium">Anda belum memiliki koleksi foto.</p>
                            <a href="{{ route('explore') }}" class="mt-4 text-xs font-bold text-indigo-400 hover:text-indigo-300">Jelajahi Galeri &rarr;</a>
                        </div>
                    @else
                        @foreach($purchasedPhotos as $photo)
                            <div class="group relative rounded-2xl overflow-hidden border border-gray-800 bg-gray-900 aspect-[4/3]">
                                <img src="{{ asset('storage/' . $photo->watermarked_path) }}" alt="{{ $photo->title }}" class="w-full h-full object-cover transition duration-500 group-hover:scale-105">
                                <div class="absolute inset-0 bg-gradient-to-t from-gray-950 via-gray-900/40 to-transparent opacity-80 transition duration-300 group-hover:opacity-90"></div>
                                
                                <div class="absolute bottom-0 left-0 right-0 p-4 transform translate-y-2 group-hover:translate-y-0 transition duration-300">
                                    <h4 class="text-sm font-bold text-white truncate">{{ $photo->title }}</h4>
                                    <p class="text-[10px] text-gray-400 mt-1 flex items-center gap-1.5">
                                        <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path></svg>
                                        {{ $photo->photographer->name }}
                                    </p>
                                    <a href="{{ route('photo.download', $photo->id) }}" class="mt-3 flex items-center justify-center gap-2 w-full py-2 bg-white/10 hover:bg-indigo-600 backdrop-blur-md rounded-xl text-xs font-bold text-white transition">
                                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path></svg>
                                        Unduh Resolusi Asli
                                    </a>
                                </div>
                            </div>
                        @endforeach
                    @endif
                </div>

                <!-- Tab: Saved Photos -->
                <div id="p-tab-saved" class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5 hidden animate-fade-in">
                    @if($savedPhotos->isEmpty())
                        <div class="col-span-full flex flex-col items-center justify-center py-16 border-2 border-dashed border-gray-800 rounded-3xl bg-gray-900/20">
                            <svg class="w-12 h-12 text-gray-700 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"></path></svg>
                            <p class="text-sm text-gray-500 font-medium">Belum ada foto yang Anda simpan.</p>
                        </div>
                    @else
                        @foreach($savedPhotos as $photo)
                            <div class="group relative rounded-2xl overflow-hidden border border-gray-800 bg-gray-900 aspect-[4/3]">
                                <img src="{{ asset('storage/' . $photo->watermarked_path) }}" alt="{{ $photo->title }}" class="w-full h-full object-cover transition duration-500 group-hover:scale-105">
                                <div class="absolute inset-0 bg-gradient-to-t from-gray-950 via-gray-900/40 to-transparent opacity-80"></div>
                                
                                <div class="absolute bottom-0 left-0 right-0 p-4">
                                    <h4 class="text-sm font-bold text-white truncate">{{ $photo->title }}</h4>
                                    <a href="{{ route('photo.show', $photo->id) }}" class="mt-3 flex items-center justify-center gap-2 w-full py-2 border border-gray-700 hover:border-indigo-500 hover:bg-indigo-500/20 backdrop-blur-md rounded-xl text-xs font-bold text-white transition">
                                        Lihat Detail
                                    </a>
                                </div>
                            </div>
                        @endforeach
                    @endif
                </div>
            </div>

        </div>

    </div>
</div>
@endsection

@section('scripts')
<script>
    function switchProfileTab(tab) {
        const purchasedBtn = document.getElementById('p-tab-btn-purchased');
        const savedBtn = document.getElementById('p-tab-btn-saved');
        const purchasedSection = document.getElementById('p-tab-purchased');
        const savedSection = document.getElementById('p-tab-saved');

        if (tab === 'purchased') {
            purchasedBtn.classList.add('border-indigo-500', 'text-gray-100');
            purchasedBtn.classList.remove('border-transparent', 'text-gray-400');
            savedBtn.classList.add('border-transparent', 'text-gray-400');
            savedBtn.classList.remove('border-indigo-500', 'text-gray-100');
            
            purchasedSection.classList.remove('hidden');
            savedSection.classList.add('hidden');
        } else {
            savedBtn.classList.add('border-indigo-500', 'text-gray-100');
            savedBtn.classList.remove('border-transparent', 'text-gray-400');
            purchasedBtn.classList.add('border-transparent', 'text-gray-400');
            purchasedBtn.classList.remove('border-indigo-500', 'text-gray-100');
            
            savedSection.classList.remove('hidden');
            purchasedSection.classList.add('hidden');
        }
    }
</script>
@endsection
