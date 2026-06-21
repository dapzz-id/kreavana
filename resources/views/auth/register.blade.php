@extends('layouts.app')
@section('title', 'Daftar Akun Baru - KREAVANA')

@section('content')
<div class="min-h-[70vh] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
    <div class="max-w-md w-full space-y-8 glass p-8 rounded-2xl border border-gray-800 shadow-2xl relative overflow-hidden">
        
        <!-- Ambient Background Glow -->
        <div class="absolute -top-10 -right-10 w-40 h-40 bg-pink-500/10 rounded-full blur-3xl"></div>
        <div class="absolute -bottom-10 -left-10 w-40 h-40 bg-indigo-500/10 rounded-full blur-3xl"></div>

        <div class="relative">
            <h2 class="text-center text-3xl font-extrabold bg-gradient-to-r from-indigo-400 via-purple-400 to-pink-500 bg-clip-text text-transparent">
                Daftar KREAVANA
            </h2>
            <p class="mt-2 text-center text-sm text-gray-400">
                Sudah punya akun?
                <a href="{{ route('login') }}" class="font-medium text-indigo-400 hover:text-indigo-300 transition-colors">
                    silakan masuk di sini
                </a>
            </p>
        </div>

        <form class="mt-8 space-y-6 relative" action="{{ route('register') }}" method="POST">
            @csrf
            
            <div class="space-y-4">
                <div>
                    <label for="name" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Nama Lengkap</label>
                    <input id="name" name="name" type="text" required value="{{ old('name') }}"
                           class="w-full px-4 py-3 bg-gray-900 border border-gray-800 rounded-xl text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition text-sm"
                           placeholder="John Doe">
                    @error('name')
                        <p class="mt-1.5 text-xs text-red-400 font-medium">{{ $message }}</p>
                    @enderror
                </div>

                <div>
                    <label for="email" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Alamat Email</label>
                    <input id="email" name="email" type="email" required value="{{ old('email') }}"
                           class="w-full px-4 py-3 bg-gray-900 border border-gray-800 rounded-xl text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition text-sm"
                           placeholder="nama@email.com">
                    @error('email')
                        <p class="mt-1.5 text-xs text-red-400 font-medium">{{ $message }}</p>
                    @enderror
                </div>
                
                <div>
                    <label for="password" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Kata Sandi</label>
                    <input id="password" name="password" type="password" required
                           class="w-full px-4 py-3 bg-gray-900 border border-gray-800 rounded-xl text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition text-sm"
                           placeholder="Minimal 6 karakter">
                    @error('password')
                        <p class="mt-1.5 text-xs text-red-400 font-medium">{{ $message }}</p>
                    @enderror
                </div>

                <div>
                    <label for="password_confirmation" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2">Konfirmasi Kata Sandi</label>
                    <input id="password_confirmation" name="password_confirmation" type="password" required
                           class="w-full px-4 py-3 bg-gray-900 border border-gray-800 rounded-xl text-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition text-sm"
                           placeholder="Ulangi kata sandi">
                </div>
            </div>

            <div>
                <button type="submit" 
                        class="group relative w-full flex justify-center py-3 px-4 border border-transparent text-sm font-bold rounded-xl text-white bg-indigo-600 hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 shadow-lg shadow-indigo-500/25 hover:shadow-indigo-500/40 transition-all duration-200">
                    Daftar Sekarang
                </button>
            </div>

            <div class="mt-6">
                <div class="relative">
                    <div class="absolute inset-0 flex items-center">
                        <div class="w-full border-t border-gray-800"></div>
                    </div>
                    <div class="relative flex justify-center text-sm">
                        <span class="px-2 bg-gray-950 text-gray-400">Atau daftar dengan</span>
                    </div>
                </div>

                <div class="mt-6">
                    <a href="{{ route('auth.google') }}" class="w-full flex items-center justify-center gap-3 py-3 px-4 border border-gray-700 rounded-xl bg-gray-900 text-sm font-semibold text-gray-300 hover:bg-gray-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-all">
                        <svg class="w-5 h-5" viewBox="0 0 24 24">
                            <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
                            <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                            <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                            <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
                        </svg>
                        Lanjutkan dengan Google
                    </a>
                </div>
            </div>
        </form>
    </div>
</div>
@endsection
