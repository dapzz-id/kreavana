<!DOCTYPE html>
<html lang="id">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'Dashboard - KREAVANA')</title>
    <link rel="icon" type="image/png" href="{{ asset('logo.png') }}">

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">

    <!-- Vite Assets -->
    @vite(['resources/css/app.css', 'resources/js/app.js'])

    <!-- Custom Utilities -->
    <style>
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background-color: #0b0f19;
            color: #f3f4f6;
        }

        .glass {
            background: rgba(17, 24, 39, 0.7);
            backdrop-filter: blur(12px);
            border: 1px solid rgba(255, 255, 255, 0.08);
        }

        /* Custom scrollbar */
        ::-webkit-scrollbar {
            width: 8px;
        }

        ::-webkit-scrollbar-track {
            background: #0b0f19;
        }

        ::-webkit-scrollbar-thumb {
            background: #1f2937;
            border-radius: 4px;
        }

        ::-webkit-scrollbar-thumb:hover {
            background: #374151;
        }
    </style>
    @yield('styles')
</head>

<body class="min-h-screen flex flex-col md:flex-row pb-16 md:pb-0">

    <!-- Sidebar (Desktop) / Bottom Nav (Mobile) -->
    <nav class="fixed bottom-0 w-full md:relative md:w-72 bg-gray-950/90 backdrop-blur-xl border-t md:border-t-0 md:border-r border-gray-900 z-50 md:h-screen md:sticky md:top-0 flex flex-col">
        <!-- Brand / Header (Desktop Only) -->
        <div class="hidden md:flex items-center justify-center h-20 border-b border-gray-900/50">
            <a href="{{ route('home') }}" class="flex items-center gap-2.5 hover:opacity-90 transition">
                <img src="{{ asset('logo.png') }}" class="w-8 h-8 object-contain" alt="Logo">
                <span class="text-2xl font-extrabold tracking-wider bg-gradient-to-r from-indigo-400 via-purple-400 to-pink-500 bg-clip-text text-transparent">
                    kreavana
                </span>
            </a>
        </div>

        <!-- Navigation Links -->
        <div class="flex-grow flex flex-row md:flex-col justify-around md:justify-start overflow-x-auto md:overflow-y-auto px-2 py-3 md:p-4 gap-2">
            
            <div class="hidden md:block px-3 pb-2 pt-4">
                <p class="text-[10px] font-bold text-gray-500 uppercase tracking-wider">Aktivitas Anda</p>
            </div>

            <!-- Profile / Dashboard -->
            <a href="{{ route('profile') }}" class="flex flex-col md:flex-row items-center md:justify-start gap-1 md:gap-3 px-3 py-2 md:p-3 rounded-xl hover:bg-gray-900 transition-colors {{ request()->routeIs('profile') ? 'bg-indigo-500/10 text-indigo-400 border border-indigo-500/20' : 'text-gray-400' }}">
                <svg class="w-6 h-6 md:w-5 md:h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path></svg>
                <span class="text-[10px] md:text-sm font-semibold">Profil & Koleksi</span>
            </a>

            <!-- Cart -->
            <a href="{{ route('cart.index') }}" class="flex flex-col md:flex-row items-center md:justify-start gap-1 md:gap-3 px-3 py-2 md:p-3 rounded-xl hover:bg-gray-900 transition-colors {{ request()->routeIs('cart.*') ? 'bg-indigo-500/10 text-indigo-400 border border-indigo-500/20' : 'text-gray-400' }}">
                <div class="relative">
                    <svg class="w-6 h-6 md:w-5 md:h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"></path></svg>
                    @php $cartCount = count(session('cart', [])); @endphp
                    @if($cartCount > 0)
                        <span class="absolute -top-1.5 -right-1.5 bg-pink-500 text-white text-[9px] font-bold rounded-full w-4 h-4 flex items-center justify-center">{{ $cartCount }}</span>
                    @endif
                </div>
                <span class="text-[10px] md:text-sm font-semibold">Keranjang</span>
            </a>

            @if(Auth::user()->isPhotographer())
                <div class="hidden md:block px-3 pb-2 pt-6">
                    <p class="text-[10px] font-bold text-emerald-500 uppercase tracking-wider">Creator Studio</p>
                </div>

                <!-- Photographer Dashboard -->
                <a href="{{ route('photographer.dashboard') }}" class="flex flex-col md:flex-row items-center md:justify-start gap-1 md:gap-3 px-3 py-2 md:p-3 rounded-xl hover:bg-gray-900 transition-colors {{ request()->routeIs('photographer.dashboard') ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'text-gray-400' }}">
                    <svg class="w-6 h-6 md:w-5 md:h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                    <span class="text-[10px] md:text-sm font-semibold whitespace-nowrap">Dashboard Fotografer</span>
                </a>
            @endif

            <!-- Back to Gallery -->
            <div class="hidden md:block mt-auto pb-4 border-t border-gray-900/50 pt-4 px-2">
                <a href="{{ route('explore') }}" class="flex items-center justify-center gap-2 w-full px-4 py-3 rounded-xl bg-gray-900 text-gray-300 hover:text-white hover:bg-gray-800 transition text-sm font-bold">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path></svg>
                    Kembali ke Galeri
                </a>
            </div>
        </div>
    </nav>

    <!-- Main Content Area -->
    <main class="flex-grow flex flex-col bg-[#0b0f19] min-h-screen">
        
        <!-- Topbar (Mobile Only) -->
        <header class="md:hidden flex items-center justify-between px-4 py-3 bg-gray-950 border-b border-gray-900 sticky top-0 z-40">
            <a href="{{ route('home') }}" class="flex items-center gap-2">
                <img src="{{ asset('logo.png') }}" class="w-6 h-6 object-contain" alt="Logo">
                <span class="text-xl font-extrabold tracking-wider bg-gradient-to-r from-indigo-400 via-purple-400 to-pink-500 bg-clip-text text-transparent">
                    kreavana
                </span>
            </a>
            <a href="{{ route('explore') }}" class="p-2 rounded-lg bg-gray-900 text-gray-400">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path></svg>
            </a>
        </header>

        <!-- Topbar (Desktop) User Info -->
        <header class="hidden md:flex items-center justify-end px-8 py-4 bg-gray-950/30 border-b border-gray-900/50">
            <div class="flex items-center gap-4">
                <div class="text-right">
                    <p class="text-sm font-bold text-gray-200">{{ Auth::user()->name }}</p>
                    <p class="text-[10px] text-gray-500 font-semibold uppercase">{{ Auth::user()->role?->name ?? 'Tanpa Role' }}</p>
                </div>
                <div class="w-10 h-10 rounded-full bg-gradient-to-tr from-indigo-500 to-pink-500 flex items-center justify-center font-bold text-white shadow-lg">
                    {{ substr(Auth::user()->name, 0, 2) }}
                </div>
                
                <form action="{{ route('logout') }}" method="POST" class="ml-2 border-l border-gray-800 pl-4">
                    @csrf
                    <button type="submit" class="text-gray-500 hover:text-red-400 transition" title="Keluar">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path></svg>
                    </button>
                </form>
            </div>
        </header>

        <!-- Dashboard Content -->
        <div class="flex-grow p-4 md:p-8 overflow-y-auto w-full max-w-6xl mx-auto">
            
            <!-- Notifications -->
            @if(session('success'))
                <div class="mb-6 p-4 rounded-xl border border-emerald-500/20 bg-emerald-500/10 text-emerald-300 flex items-center gap-3 animate-fade-in">
                    <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                    <span class="text-sm font-medium">{{ session('success') }}</span>
                </div>
            @endif

            @if(session('error'))
                <div class="mb-6 p-4 rounded-xl border border-red-500/20 bg-red-500/10 text-red-300 flex items-center gap-3 animate-fade-in">
                    <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                    <span class="text-sm font-medium">{{ session('error') }}</span>
                </div>
            @endif

            @yield('content')
        </div>
    </main>

    <style>
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-10px); }
            to { opacity: 1; transform: translateY(0); }
        }
        .animate-fade-in {
            animation: fadeIn 0.3s ease-out forwards;
        }
    </style>
    @yield('scripts')
</body>

</html>
