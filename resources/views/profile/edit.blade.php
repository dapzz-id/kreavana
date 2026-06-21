@extends('layouts.app')
@section('title', 'Edit Profil - KREAVANA')

@section('styles')
<style>[x-cloak]{display:none!important}</style>
@endsection

@section('content')
<div class="max-w-3xl mx-auto px-4 py-10" x-data="{ tab: 'profile', faceStep: 'idle', previewUrl: null }">
    
    <!-- Page Header -->
    <div class="mb-8">
        <h1 class="text-2xl font-bold text-slate-900 dark:text-white">Pengaturan Profil</h1>
        <p class="text-slate-500 dark:text-gray-400 text-sm mt-1">Kelola informasi, privasi, dan keamanan akun Anda.</p>
    </div>

    <!-- Success / Error Flash -->
    @if(session('success'))
        <div class="mb-6 p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-xl text-emerald-300 text-sm flex items-center gap-3">
            <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
            {{ session('success') }}
        </div>
    @endif
    @if($errors->any())
        <div class="mb-6 p-4 bg-red-500/10 border border-red-500/30 rounded-xl text-red-300 text-sm">
            <ul class="list-disc list-inside space-y-1">
                @foreach($errors->all() as $e) <li>{{ $e }}</li> @endforeach
            </ul>
        </div>
    @endif

    <!-- Tab Navigation -->
    <div class="flex gap-1 bg-white dark:bg-slate-800/50 p-1 rounded-xl mb-8 border border-slate-200 dark:border-slate-700">
        <button @click="tab='profile'" :class="tab==='profile' ? 'bg-slate-100 text-slate-900 dark:bg-slate-700 dark:text-white shadow' : 'text-slate-500 hover:text-slate-900 dark:text-gray-400 dark:hover:text-slate-800 dark:text-gray-200'" class="flex-1 py-2.5 text-sm font-semibold rounded-lg transition-all">Profil</button>
        <button @click="tab='security'" :class="tab==='security' ? 'bg-slate-100 text-slate-900 dark:bg-slate-700 dark:text-white shadow' : 'text-slate-500 hover:text-slate-900 dark:text-gray-400 dark:hover:text-slate-800 dark:text-gray-200'" class="flex-1 py-2.5 text-sm font-semibold rounded-lg transition-all">Keamanan</button>
        <button @click="tab='face'" :class="tab==='face' ? 'bg-slate-100 text-slate-900 dark:bg-slate-700 dark:text-white shadow' : 'text-slate-500 hover:text-slate-900 dark:text-gray-400 dark:hover:text-slate-800 dark:text-gray-200'" class="flex-1 py-2.5 text-sm font-semibold rounded-lg transition-all">
            <span class="flex items-center justify-center gap-1.5">
                <span class="w-2 h-2 rounded-full bg-indigo-400 animate-pulse"></span>
                RoboYu AI
            </span>
        </button>
    </div>

    <!-- ─── TAB: PROFILE ─────────────────────────────────── -->
    <div x-show="tab==='profile'" x-cloak>

        <!-- Avatar Upload -->
        <div class="bg-white dark:bg-slate-800/60 rounded-2xl border border-slate-200 dark:border-slate-700 p-6 mb-6">
            <h2 class="text-sm font-bold text-slate-700 dark:text-gray-300 uppercase tracking-wider mb-5">Foto Profil</h2>
            <div class="flex items-center gap-6">
                <div class="relative">
                    <img id="avatar-preview" src="{{ $user->profile_photo_url }}" class="w-24 h-24 rounded-full object-cover border-2 border-indigo-500/50" alt="Avatar">
                    <label for="photo-input" class="absolute -bottom-1 -right-1 w-8 h-8 bg-indigo-600 hover:bg-indigo-500 rounded-full flex items-center justify-center cursor-pointer transition shadow-lg">
                        <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                    </label>
                </div>
                <div class="text-sm text-slate-500 dark:text-gray-400">
                    <p class="font-semibold text-slate-800 dark:text-gray-200 mb-1">{{ $user->name }}</p>
                    <p>JPG, PNG, atau WebP. Maks 5MB.</p>
                    <form id="photo-form" action="{{ route('profile.photo') }}" method="POST" enctype="multipart/form-data">
                        @csrf
                        <input id="photo-input" type="file" name="photo" class="hidden" accept="image/*" onchange="previewAndSubmit(this)">
                    </form>
                </div>
            </div>
        </div>

        <!-- Profile Info Form -->
        <form action="{{ route('profile.update') }}" method="POST" class="bg-white dark:bg-slate-800/60 rounded-2xl border border-slate-200 dark:border-slate-700 p-6 space-y-5">
            @csrf
            @method('POST')
            <h2 class="text-sm font-bold text-slate-700 dark:text-gray-300 uppercase tracking-wider">Informasi Akun</h2>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
                <div>
                    <label class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Nama Lengkap</label>
                    <input type="text" name="name" value="{{ old('name', $user->name) }}" required
                        class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-slate-900 dark:text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm transition">
                </div>
                <div>
                    <label class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Username</label>
                    <div class="relative">
                        <span class="absolute inset-y-0 left-4 flex items-center text-gray-500 text-sm">@</span>
                        <input type="text" name="username" value="{{ old('username', $user->username) }}"
                            class="w-full pl-8 pr-4 py-3 bg-slate-50 dark:bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-slate-900 dark:text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm transition"
                            placeholder="username_anda">
                    </div>
                </div>
            </div>

            <div>
                <label class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Email</label>
                <input type="email" name="email" value="{{ old('email', $user->email) }}" required
                    class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-slate-900 dark:text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm transition">
            </div>

            <div>
                <label class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Bio</label>
                <textarea name="bio" rows="3" maxlength="500" placeholder="Ceritakan sedikit tentang diri Anda..."
                    class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-slate-900 dark:text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm transition resize-none">{{ old('bio', $user->bio) }}</textarea>
            </div>

            <div>
                <label class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Website</label>
                <input type="url" name="website" value="{{ old('website', $user->website) }}"
                    class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-slate-900 dark:text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm transition"
                    placeholder="https://portofolio-anda.com">
            </div>

            <!-- Lokasi Kerja (Photographers/Videographers only) -->
            <div class="border-t border-slate-700 pt-5 space-y-4">
                <div>
                    <h3 class="text-sm font-bold text-slate-700 dark:text-gray-300 uppercase tracking-wider">Lokasi Kerja (Koordinat Peta)</h3>
                    <p class="text-xs text-slate-500 dark:text-gray-400 mt-1">Mengatur koordinat lokasi agar calon klien dapat menemukan studio/karya Anda di Peta.</p>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
                    <div>
                        <label class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Latitude (Garis Lintang)</label>
                        <input type="number" step="any" name="latitude" id="latitude-input" value="{{ old('latitude', $user->latitude) }}"
                            class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-slate-900 dark:text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm transition"
                            placeholder="Contoh: -6.2088">
                    </div>
                    <div>
                        <label class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Longitude (Garis Bujur)</label>
                        <input type="number" step="any" name="longitude" id="longitude-input" value="{{ old('longitude', $user->longitude) }}"
                            class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-slate-900 dark:text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm transition"
                            placeholder="Contoh: 106.8456">
                    </div>
                </div>

                <div class="flex items-center gap-3">
                    <button type="button" onclick="getCurrentLocation()" class="px-4 py-2 bg-indigo-600/20 hover:bg-indigo-600/35 border border-indigo-500/30 text-indigo-300 rounded-xl text-xs font-bold transition flex items-center gap-1.5 focus:outline-none">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                        </svg>
                        Gunakan Lokasi Saya Saat Ini
                    </button>
                    <span id="geo-status" class="text-xs text-gray-500"></span>
                </div>
            </div>

            <button type="submit" class="w-full py-3 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-xl transition shadow-lg shadow-indigo-500/20">
                Simpan Perubahan
            </button>
        </form>

        <!-- Photographer Request -->
        @if($user->isUser())
        <div class="mt-6 bg-slate-800/60 rounded-2xl border border-indigo-500/20 p-6">
            <h2 class="text-sm font-bold text-slate-700 dark:text-gray-300 uppercase tracking-wider mb-3">Daftar sebagai Fotografer</h2>
            
            @if(isset($photographerRequest) && $photographerRequest)
                @if($photographerRequest->status === 'pending')
                    <div class="p-4 rounded-xl border border-yellow-500/20 bg-yellow-500/5 text-center space-y-2 mb-4">
                        <span class="px-2 py-0.5 rounded bg-yellow-500/10 border border-yellow-500/20 text-yellow-500 text-[10px] font-extrabold uppercase tracking-wider">Pengajuan Diproses</span>
                        <p class="text-xs text-slate-500 dark:text-gray-400 leading-relaxed">Berkas KTP dan NPWP Anda sudah kami terima dan sedang diverifikasi oleh admin. Mohon ditunggu.</p>
                    </div>
                @elseif($photographerRequest->status === 'rejected')
                    <div class="p-4 rounded-xl border border-red-500/20 bg-red-500/5 space-y-2 mb-4">
                        <div class="text-center">
                            <span class="px-2 py-0.5 rounded bg-red-500/10 border border-red-500/20 text-red-400 text-[10px] font-extrabold uppercase tracking-wider">Pengajuan Ditolak</span>
                        </div>
                        <p class="text-xs text-slate-500 dark:text-gray-400 leading-relaxed"><strong>Catatan Admin:</strong> <span class="text-red-300">"{{ $photographerRequest->admin_notes }}"</span></p>
                    </div>
                    @include('partials.photographer_form')
                @endif
            @else
                <p class="text-sm text-slate-500 dark:text-gray-400 mb-4">Ajukan permohonan untuk menjadi fotografer dan mulai menjual karya foto Anda.</p>
                @include('partials.photographer_form')
            @endif
        </div>
        @endif
    </div>

    <!-- ─── TAB: SECURITY ─────────────────────────────────── -->
    <div x-show="tab==='security'" x-cloak>
        <form action="{{ route('profile.password') }}" method="POST" class="bg-white dark:bg-slate-800/60 rounded-2xl border border-slate-200 dark:border-slate-700 p-6 space-y-5">
            @csrf
            <h2 class="text-sm font-bold text-slate-700 dark:text-gray-300 uppercase tracking-wider">Ganti Kata Sandi</h2>

            <div>
                <label class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Kata Sandi Saat Ini</label>
                <input type="password" name="current_password" required
                    class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-slate-900 dark:text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm transition"
                    placeholder="••••••••">
            </div>
            <div>
                <label class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Kata Sandi Baru</label>
                <input type="password" name="password" required minlength="8"
                    class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-slate-900 dark:text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm transition"
                    placeholder="Minimal 8 karakter">
            </div>
            <div>
                <label class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Konfirmasi Kata Sandi Baru</label>
                <input type="password" name="password_confirmation" required
                    class="w-full px-4 py-3 bg-slate-50 dark:bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-slate-900 dark:text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm transition"
                    placeholder="Ketik ulang kata sandi baru">
            </div>

            <button type="submit" class="w-full py-3 bg-red-600 hover:bg-red-500 text-white font-bold rounded-xl transition">
                Ganti Kata Sandi
            </button>
        </form>
    </div>

    <!-- ─── TAB: ROBOYU AI FACE SCAN ──────────────────────── -->
    <div x-show="tab==='face'" x-cloak>
        <div class="bg-slate-800/60 rounded-2xl border border-indigo-500/30 p-6">
            <!-- Header -->
            <div class="flex items-center gap-3 mb-6">
                <div class="w-10 h-10 bg-indigo-500/20 rounded-xl flex items-center justify-center">
                    <svg class="w-5 h-5 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 3H5a2 2 0 00-2 2v4m6-6h10a2 2 0 012 2v4M9 3v18m0 0h10a2 2 0 002-2V9M9 21H5a2 2 0 01-2-2V9m0 0h18"/></svg>
                </div>
                <div>
                    <h2 class="font-bold text-slate-900 dark:text-white">RoboYu Face Scan</h2>
                    <p class="text-xs text-slate-500 dark:text-gray-400">AI-powered facial recognition untuk menemukan foto Anda di setiap event</p>
                </div>
            </div>

            <!-- Step: IDLE -->
            <div x-show="faceStep === 'idle'">
                @if($user->face_embeddings)
                    <div class="p-4 bg-emerald-500/10 border border-emerald-500/20 rounded-xl mb-6">
                        <p class="text-sm text-emerald-300 font-semibold flex items-center gap-2">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                            Selfie terdaftar — Status: <span class="uppercase">{{ $user->face_embeddings['status'] ?? 'unknown' }}</span>
                        </p>
                        <p class="text-xs text-slate-500 dark:text-gray-400 mt-1">Diunggah: {{ isset($user->face_embeddings['uploaded_at']) ? \Carbon\Carbon::parse($user->face_embeddings['uploaded_at'])->diffForHumans() : '-' }}</p>
                    </div>
                @endif

                <div class="text-center py-8">
                    <div class="w-32 h-32 mx-auto mb-6 rounded-full border-2 border-dashed border-indigo-500/50 flex items-center justify-center relative overflow-hidden bg-slate-50 dark:bg-slate-50 dark:bg-slate-900/50">
                        <img x-show="previewUrl" :src="previewUrl" class="absolute inset-0 w-full h-full object-cover rounded-full" x-cloak>
                        <svg x-show="!previewUrl" class="w-14 h-14 text-indigo-400/60" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M5.121 17.804A13.937 13.937 0 0112 16c2.5 0 4.847.655 6.879 1.804M15 10a3 3 0 11-6 0 3 3 0 016 0zm6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                    </div>
                    <p class="text-slate-500 dark:text-gray-400 text-sm mb-6">Unggah foto selfie Anda yang jelas. Sistem AI akan mengekstrak data wajah untuk mencocokkan foto di galeri event secara otomatis.</p>
                    
                    <label class="px-6 py-3 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-xl cursor-pointer transition shadow-lg shadow-indigo-500/20 inline-flex items-center gap-2">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"/></svg>
                        Pilih Foto Selfie
                        <input type="file" class="hidden" accept="image/jpg,image/jpeg,image/png" @change="handleFaceScan($event)">
                    </label>
                </div>
            </div>

            <!-- Step: UPLOADING -->
            <div x-show="faceStep === 'uploading'" x-cloak class="text-center py-12">
                <div class="w-16 h-16 mx-auto mb-4 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin"></div>
                <p class="text-slate-700 dark:text-gray-300 font-semibold">Mengunggah & memproses wajah...</p>
                <p class="text-gray-500 text-sm mt-1">Harap tunggu sebentar</p>
            </div>

            <!-- Step: DONE -->
            <div x-show="faceStep === 'done'" x-cloak class="text-center py-8">
                <div class="w-16 h-16 mx-auto mb-4 bg-emerald-500/20 rounded-full flex items-center justify-center">
                    <svg class="w-8 h-8 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
                </div>
                <h3 class="text-xl font-bold text-emerald-300">Berhasil!</h3>
                <p class="text-slate-500 dark:text-gray-400 text-sm mt-2 mb-6">Data wajah Anda telah dikirim ke sistem AI RoboYu. Proses pencocokan akan berjalan di latar belakang.</p>
                <a href="{{ route('explore') }}" class="px-6 py-3 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-xl transition">
                    Cari Foto Saya di Galeri
                </a>
            </div>
        </div>
    </div>

</div>
@endsection

@section('scripts')
<script>
function previewAndSubmit(input) {
    if (input.files && input.files[0]) {
        const reader = new FileReader();
        reader.onload = e => document.getElementById('avatar-preview').src = e.target.result;
        reader.readAsDataURL(input.files[0]);
        // Auto-submit the form
        document.getElementById('photo-form').submit();
    }
}

function handleFaceScan(event) {
    const file = event.target.files[0];
    if (!file) return;

    // Preview
    const reader = new FileReader();
    reader.onload = e => {
        Alpine.store('previewUrl', e.target.result); // won't work directly, set via Alpine
    };
    reader.readAsDataURL(file);

    // Set Alpine state (access component)
    const component = Alpine.$data(document.querySelector('[x-data]'));
    
    const fileReader = new FileReader();
    fileReader.onload = e => component.previewUrl = e.target.result;
    fileReader.readAsDataURL(file);

    component.faceStep = 'uploading';

    const formData = new FormData();
    formData.append('selfie', file);
    formData.append('_token', document.querySelector('meta[name="csrf-token"]').content);

    fetch('{{ route("profile.face_scan") }}', {
        method: 'POST',
        body: formData,
    })
    .then(r => r.json())
    .then(data => {
        if (data.success) {
            component.faceStep = 'done';
        } else {
            component.faceStep = 'idle';
            alert('Gagal memproses selfie. Coba lagi.');
        }
    })
    .catch(() => {
        component.faceStep = 'idle';
        alert('Terjadi kesalahan sambungan.');
    });
}

function getCurrentLocation() {
    const status = document.getElementById('geo-status');
    const latInput = document.getElementById('latitude-input');
    const lngInput = document.getElementById('longitude-input');

    if (!navigator.geolocation) {
        status.textContent = 'Geolocation tidak didukung oleh browser Anda.';
        return;
    }

    status.textContent = 'Mendeteksi lokasi...';
    status.className = 'text-xs text-indigo-400 animate-pulse';

    navigator.geolocation.getCurrentPosition(
        (position) => {
            latInput.value = position.coords.latitude.toFixed(8);
            lngInput.value = position.coords.longitude.toFixed(8);
            status.textContent = 'Lokasi berhasil dideteksi!';
            status.className = 'text-xs text-emerald-400';
        },
        (error) => {
            status.textContent = 'Gagal mendeteksi lokasi: ' + error.message;
            status.className = 'text-xs text-red-400';
        },
        {
            enableHighAccuracy: true,
            timeout: 10000,
            maximumAge: 0
        }
    );
}
</script>
@endsection
