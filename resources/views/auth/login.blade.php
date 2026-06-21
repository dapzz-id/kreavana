@extends('layouts.app')
@section('title', 'Masuk - KREAVANA')

@section('content')
<div class="min-h-[80vh] flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8 relative overflow-hidden">
    <!-- Ambient Background Glows -->
    <div class="absolute top-1/4 -right-20 w-72 h-72 bg-indigo-600/20 rounded-full blur-[100px] pointer-events-none"></div>
    <div class="absolute bottom-1/4 -left-20 w-72 h-72 bg-pink-600/20 rounded-full blur-[100px] pointer-events-none"></div>

    <div class="max-w-md w-full space-y-8 bg-white/80 dark:bg-slate-800/60 backdrop-blur-xl p-10 rounded-3xl border border-slate-200 dark:border-slate-200 dark:border-gray-700 shadow-2xl relative z-10">
        
        <div class="relative text-center">
            <h2 class="text-3xl font-extrabold bg-gradient-to-r from-indigo-400 via-purple-400 to-pink-500 bg-clip-text text-transparent">
                Masuk ke KREAVANA
            </h2>
            <p class="mt-3 text-sm text-slate-500 dark:text-gray-400">
                Belum punya akun?
                <a href="{{ route('register') }}" class="font-medium text-indigo-400 hover:text-indigo-300 transition-colors underline underline-offset-4">
                    Buat akun gratis
                </a>
            </p>
        </div>

        <form class="mt-8 space-y-6" action="{{ route('login') }}" method="POST">
            @csrf
            
            <div class="space-y-5">
                <div>
                    <label for="email" class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Alamat Email</label>
                    <div class="relative">
                        <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                            <svg class="h-5 w-5 text-slate-400 dark:text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207"></path></svg>
                        </div>
                        <input id="email" name="email" type="email" autocomplete="email" required value="{{ old('email') }}"
                               class="w-full pl-11 pr-4 py-3.5 bg-white dark:bg-slate-900/50 border border-slate-300 dark:border-slate-200 dark:border-gray-700 rounded-xl text-slate-900 dark:text-gray-200 placeholder-slate-400 dark:placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition text-sm shadow-inner"
                               placeholder="nama@email.com">
                    </div>
                    @error('email')
                        <p class="mt-1.5 text-xs text-red-400 font-medium flex items-center gap-1">
                            <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path></svg>
                            {{ $message }}
                        </p>
                    @enderror
                </div>
                
                <div>
                    <label for="password" class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Kata Sandi</label>
                    <div class="relative">
                        <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                            <svg class="h-5 w-5 text-slate-400 dark:text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path></svg>
                        </div>
                        <input id="password" name="password" type="password" autocomplete="current-password" required
                               class="w-full pl-11 pr-4 py-3.5 bg-white dark:bg-slate-900/50 border border-slate-300 dark:border-slate-200 dark:border-gray-700 rounded-xl text-slate-900 dark:text-gray-200 placeholder-slate-400 dark:placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition text-sm shadow-inner"
                               placeholder="••••••••">
                    </div>
                    @error('password')
                        <p class="mt-1.5 text-xs text-red-400 font-medium flex items-center gap-1">
                            <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path></svg>
                            {{ $message }}
                        </p>
                    @enderror
                </div>
            </div>

            <div class="flex items-center justify-between mt-2">
                <div class="flex items-center">
                    <input id="remember" name="remember" type="checkbox" 
                           class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-slate-300 dark:border-slate-200 dark:border-gray-700 rounded bg-white dark:bg-slate-900 cursor-pointer">
                    <label for="remember" class="ml-2 block text-sm font-medium text-slate-500 dark:text-gray-400 cursor-pointer select-none">
                        Ingat Saya
                    </label>
                </div>
                <div class="text-sm">
                    <a href="#" class="font-medium text-indigo-400 hover:text-indigo-300 transition-colors">Lupa sandi?</a>
                </div>
            </div>

            <div class="pt-2">
                <button type="submit" 
                        class="w-full flex justify-center py-3.5 px-4 rounded-xl text-sm font-bold text-white bg-indigo-600 hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-900 focus:ring-indigo-500 shadow-lg shadow-indigo-500/25 transition-all duration-200">
                    Masuk Sekarang
                </button>
            </div>

            <div class="mt-8">
                <div class="relative">
                    <div class="absolute inset-0 flex items-center">
                        <div class="w-full border-t border-slate-200 dark:border-gray-700"></div>
                    </div>
                    <div class="relative flex justify-center text-sm">
                        <span class="px-3 bg-white dark:bg-slate-800 text-slate-500 dark:text-gray-500">Atau masuk dengan</span>
                    </div>
                </div>

                <div class="mt-6">
                    <a href="{{ route('auth.google') }}" class="w-full flex items-center justify-center gap-3 py-3 px-4 border border-slate-200 dark:border-gray-700 rounded-xl bg-white dark:bg-slate-900/80 text-sm font-semibold text-slate-700 dark:text-gray-300 hover:bg-slate-50 dark:hover:bg-gray-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-900 focus:ring-indigo-500 transition-all">
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
