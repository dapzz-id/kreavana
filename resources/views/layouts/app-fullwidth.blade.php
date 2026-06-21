<!DOCTYPE html>
<html lang="id">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'KREAVANA - Instagram & Marketplace Foto Premium')</title>
    <link rel="icon" type="image/png" href="{{ asset('logo.png') }}">

    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap"
        rel="stylesheet">

    <!-- Vite Assets -->
    @vite(['resources/css/app.css', 'resources/js/app.js'])

    <style>
        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            /* Tailwind handles the background and text color via classes on body */
        }
        /* Custom scrollbar */
        ::-webkit-scrollbar {
            width: 8px;
            height: 8px;
        }
        /* Light mode scrollbar */
        ::-webkit-scrollbar-track {
            background: #f8fafc; /* slate-50 */
        }
        ::-webkit-scrollbar-thumb {
            background: #cbd5e1; /* slate-300 */
            border-radius: 4px;
        }
        ::-webkit-scrollbar-thumb:hover {
            background: #94a3b8; /* slate-400 */
        }
        /* Dark mode scrollbar */
        html.dark ::-webkit-scrollbar-track {
            background: #0f172a; /* slate-900 */
        }
        html.dark ::-webkit-scrollbar-thumb {
            background: #334155; /* slate-700 */
            border-radius: 4px;
        }
        html.dark ::-webkit-scrollbar-thumb:hover {
            background: #475569; /* slate-600 */
        }
    </style>
    @yield('styles')
    <script>
        // Check local storage for theme
        if (localStorage.theme === 'dark' || (!('theme' in localStorage) && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
            document.documentElement.classList.add('dark');
        } else {
            document.documentElement.classList.remove('dark');
        }
    </script>
</head>

<body class="bg-slate-50 text-slate-900 dark:bg-slate-900 dark:text-slate-50 transition-colors duration-300">
    <div id="app" class="flex min-h-screen relative pb-16 md:pb-0">
        
        <!-- Mobile Top Header -->
        <header class="md:hidden fixed top-0 left-0 w-full h-14 bg-white/95 dark:bg-slate-900/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800 flex items-center justify-between px-4 z-40">
            <a href="{{ route('home') }}" class="flex items-center gap-2">
                <img src="{{ asset('logo.png') }}" class="w-6 h-6 object-contain" alt="Logo">
                <span class="text-xl font-extrabold bg-gradient-to-r from-indigo-400 to-pink-500 bg-clip-text text-transparent">
                    KREAVANA
                </span>
            </a>
            @auth
            <a href="{{ route('messages.inbox') }}" class="relative text-slate-500 hover:text-slate-900 dark:text-gray-400 dark:hover:text-white transition">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/></svg>
                @php $unread = Auth::user()->unreadMessageCount(); @endphp
                @if($unread > 0)
                    <span class="absolute -top-1 -right-1 w-3 h-3 bg-red-500 rounded-full border border-slate-900"></span>
                @endif
            </a>
            @else
            <a href="{{ route('login') }}" class="text-sm font-bold text-indigo-400">Masuk</a>
            @endauth
        </header>

        <!-- No Sidebar - Full Width Layout -->

        <!-- Added pt-14 for mobile header, pb-20 for bottom nav on mobile -->
        <main class="flex-1 min-w-0 w-full pt-14 pb-20 md:pt-0 md:pb-0 transition-all duration-300">
            @yield('content')
        </main>
    </div>

    @vite('resources/js/app.js')
    @yield('scripts')
</body>

</html>