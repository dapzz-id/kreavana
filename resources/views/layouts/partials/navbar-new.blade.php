<nav class="sticky top-0 z-50 bg-slate-900/80 backdrop-blur-md border-b border-gray-800 shadow-sm">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
            <div class="flex">
                <div class="flex-shrink-0 flex items-center">
                    <a href="{{ route('dashboard') }}" class="flex items-center gap-2">
                        <img src="{{ asset('logo.png') }}" class="w-8 h-8 object-contain" alt="Logo">
                        <span class="text-2xl font-extrabold bg-gradient-to-r from-indigo-400 via-purple-400 to-pink-500 bg-clip-text text-transparent">
                            KREAVANA
                        </span>
                    </a>
                </div>
            </div>
            <div class="hidden sm:ml-6 sm:flex sm:items-center space-x-4">
                <a href="{{ route('explore') }}" class="text-sm font-semibold text-gray-300 hover:text-white transition-colors">Explore</a>
                @auth
                <!-- Profile dropdown -->
                <div class="ml-3 relative" x-data="{ open: false }">
                    <div>
                        <button @click="open = !open" type="button" class="max-w-xs bg-gray-800 flex items-center text-sm rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-900 focus:ring-indigo-500 ring-1 ring-gray-700 hover:ring-indigo-400 transition" id="user-menu-button" aria-expanded="false" aria-haspopup="true">
                            <span class="sr-only">Open user menu</span>
                            <img class="h-8 w-8 rounded-full object-cover" src="{{ Auth::user()->profile_photo_url ?? 'https://ui-avatars.com/api/?name=' . urlencode(Auth::user()->name) . '&background=4f46e5&color=fff' }}" alt="">
                        </button>
                    </div>
                    <!-- Dropdown menu -->
                    <div x-show="open" @click.away="open = false" x-transition:enter="transition ease-out duration-100" x-transition:enter-start="transform opacity-0 scale-95" x-transition:enter-end="transform opacity-100 scale-100" x-transition:leave="transition ease-in duration-75" x-transition:leave-start="transform opacity-100 scale-100" x-transition:leave-end="transform opacity-0 scale-95" class="origin-top-right absolute right-0 mt-2 w-48 rounded-xl shadow-lg shadow-indigo-500/10 py-1 bg-gray-800 ring-1 ring-white/10 focus:outline-none" role="menu" aria-orientation="vertical" aria-labelledby="user-menu-button" tabindex="-1" style="display: none;">
                        <a href="{{ route('dashboard') }}" class="block px-4 py-2 text-sm text-gray-200 hover:bg-gray-700 hover:text-white transition-colors" role="menuitem">Dashboard</a>
                        <a href="{{ route('profile') }}" class="block px-4 py-2 text-sm text-gray-200 hover:bg-gray-700 hover:text-white transition-colors" role="menuitem">Profil Saya</a>
                        <a href="{{ route('profile.edit') }}" class="block px-4 py-2 text-sm text-gray-200 hover:bg-gray-700 hover:text-white transition-colors" role="menuitem">Pengaturan Profil</a>
                        <div class="border-t border-gray-700 my-1"></div>
                        <form method="POST" action="{{ route('logout') }}">
                            @csrf
                            <button type="submit" class="w-full text-left block px-4 py-2 text-sm text-red-400 hover:bg-gray-700 hover:text-red-300 transition-colors" role="menuitem">
                                Keluar
                            </button>
                        </form>
                    </div>
                </div>
                @else
                    <a href="{{ route('login') }}" class="text-sm font-medium text-gray-300 hover:text-white transition-colors">Masuk</a>
                    <a href="{{ route('register') }}" class="ml-4 text-sm font-bold text-white bg-indigo-600 hover:bg-indigo-500 px-5 py-2.5 rounded-xl shadow-lg shadow-indigo-500/25 transition-all">Daftar Gratis</a>
                @endauth
            </div>
        </div>
    </div>
</nav>
