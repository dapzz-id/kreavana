<aside class="fixed bottom-0 md:sticky md:top-0 left-0 w-full md:w-20 lg:w-64 h-16 md:h-screen bg-white/95 dark:bg-slate-900/95 md:bg-white dark:md:bg-slate-900 border-t md:border-t-0 md:border-r border-slate-200 dark:border-slate-800 flex flex-row md:flex-col justify-between z-50 transition-all duration-300 backdrop-blur-md md:backdrop-blur-none flex-shrink-0">
    
    <div class="flex flex-row md:flex-col w-full">
        <!-- Logo (Desktop Only) -->
        <div class="hidden md:flex h-16 items-center justify-center lg:justify-between lg:px-6 border-b border-slate-200 dark:border-slate-800 relative" @auth x-data="notificationDropdown()" @endauth>
            <div class="flex items-center">
                <a href="{{ route('dashboard') }}" class="flex items-center gap-2.5">
                    <img src="{{ asset('logo.png') }}" class="w-8 h-8 object-contain" alt="Logo">
                    <span class="text-2xl font-extrabold bg-gradient-to-r from-indigo-400 via-purple-400 to-pink-500 bg-clip-text text-transparent hidden lg:block">
                        KREAVANA
                    </span>
                </a>
            </div>

            @auth
            <!-- Notification Bell Icon and Dropdown -->
            <div class="relative hidden lg:block">
                <button @click="toggle()" class="relative p-1.5 text-slate-500 hover:text-slate-900 dark:text-gray-400 dark:hover:text-slate-900 dark:text-white rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800/80 transition-colors focus:outline-none">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
                    </svg>
                    <span x-show="unreadCount > 0" class="absolute top-1.5 right-1.5 w-2.5 h-2.5 bg-red-500 rounded-full ring-2 ring-white dark:ring-slate-900 animate-pulse" x-cloak></span>
                </button>

                <!-- Dropdown Menu -->
                <div x-show="open" 
                     @click.away="open = false" 
                     x-transition:enter="transition ease-out duration-200"
                     x-transition:enter-start="opacity-0 translate-y-1"
                     x-transition:enter-end="opacity-100 translate-y-0"
                     x-transition:leave="transition ease-in duration-150"
                     x-transition:leave-start="opacity-100 translate-y-0"
                     x-transition:leave-end="opacity-0 translate-y-1"
                     class="absolute top-11 right-0 w-80 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800/80 rounded-2xl shadow-2xl py-2 z-[100] mt-2 overflow-hidden backdrop-blur-md"
                     x-cloak>
                    
                    <!-- Dropdown Header -->
                    <div class="px-4 py-2 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between">
                        <span class="text-xs font-bold text-slate-800 dark:text-gray-100 uppercase tracking-wider">Notifikasi</span>
                        <button x-show="unreadCount > 0" @click="markAllAsRead()" class="text-[10px] font-bold text-indigo-400 hover:text-indigo-300 transition-colors focus:outline-none">
                            Tandai semua dibaca
                        </button>
                    </div>

                    <!-- Dropdown Content / Notification List -->
                    <div class="max-h-80 overflow-y-auto divide-y divide-slate-200 dark:divide-slate-800/40">
                        <div x-show="loading" class="flex flex-col items-center justify-center py-8 text-slate-400 dark:text-gray-500 space-y-2">
                            <svg class="animate-spin h-5 w-5 text-indigo-400" fill="none" viewBox="0 0 24 24">
                                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                            </svg>
                            <span class="text-[10px] uppercase font-bold tracking-wider">Memuat...</span>
                        </div>

                        <div x-show="!loading && notifications.length === 0" class="px-4 py-8 text-center text-slate-400 dark:text-gray-500 text-xs">
                            Tidak ada notifikasi baru
                        </div>

                        <div x-show="!loading && notifications.length > 0">
                            <template x-for="item in notifications" :key="item.id">
                                <div :class="item.read_at ? 'opacity-60 hover:opacity-100' : 'bg-indigo-500/5 hover:bg-indigo-500/10'" class="transition-all duration-200">
                                    <a :href="item.action_url" @click.prevent="markAsRead(item.id, item.action_url)" class="flex gap-3 px-4 py-3 items-start">
                                        <!-- Notification Type Icon -->
                                        <div class="flex-shrink-0 mt-0.5">
                                            <div class="w-8 h-8 rounded-xl flex items-center justify-center"
                                                 :class="{
                                                     'bg-pink-500/10 text-pink-500': item.type === 'like',
                                                     'bg-blue-500/10 text-blue-400': item.type === 'comment',
                                                     'bg-emerald-500/10 text-emerald-400': item.type === 'purchase',
                                                     'bg-amber-500/10 text-amber-400': item.type === 'deposit',
                                                     'bg-teal-500/10 text-teal-400': item.type === 'approval',
                                                     'bg-rose-500/10 text-rose-400': item.type === 'rejection',
                                                     'bg-indigo-500/10 text-indigo-400': ['like', 'comment', 'purchase', 'deposit', 'approval', 'rejection'].indexOf(item.type) === -1
                                                 }">
                                                <!-- Like Icon -->
                                                <svg x-show="item.type === 'like'" class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>
                                                <!-- Comment Icon -->
                                                <svg x-show="item.type === 'comment'" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/></svg>
                                                <!-- Purchase Icon -->
                                                <svg x-show="item.type === 'purchase'" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/></svg>
                                                <!-- Deposit Icon -->
                                                <svg x-show="item.type === 'deposit'" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                                                <!-- Approval Icon -->
                                                <svg x-show="item.type === 'approval'" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                                                <!-- Rejection Icon -->
                                                <svg x-show="item.type === 'rejection'" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                                                <!-- Info Icon -->
                                                <svg x-show="['like', 'comment', 'purchase', 'deposit', 'approval', 'rejection'].indexOf(item.type) === -1" class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                                            </div>
                                        </div>

                                        <!-- Notification Content -->
                                        <div class="flex-grow min-w-0">
                                            <p class="text-xs font-bold text-slate-800 dark:text-gray-200" x-text="item.title"></p>
                                            <p class="text-[11px] text-slate-500 dark:text-gray-400 mt-0.5 leading-relaxed break-words" x-text="item.message"></p>
                                            <span class="text-[9px] text-slate-400 dark:text-gray-500 block mt-1" x-text="item.created_at"></span>
                                        </div>
                                    </a>
                                </div>
                            </template>
                        </div>
                    </div>
                </div>
            </div>
            @endauth
        </div>

        <!-- Navigation Links (Horizontal on Mobile, Vertical on Desktop) -->
        <nav class="flex flex-row md:flex-col w-full justify-around md:justify-start mt-0 md:mt-4 px-2 lg:px-4 md:gap-2 items-center md:items-stretch h-full md:h-auto">

            <!-- Home/Dashboard -->
            <a href="{{ route('dashboard') }}"
               class="flex items-center {{ !Auth::check() ? 'hidden' : '' }} justify-center lg:justify-start gap-4 p-2 md:px-3 md:py-3 rounded-xl transition group flex-1 md:flex-none
               {{ request()->routeIs('dashboard') ? 'bg-indigo-50 text-indigo-600 dark:bg-slate-800 dark:text-white' : 'text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:text-gray-400 dark:hover:bg-slate-800/60 dark:hover:text-slate-900 dark:text-white' }}">
                <svg class="w-6 h-6 md:w-6 md:h-6 flex-shrink-0" fill="{{ request()->routeIs('dashboard') ? 'currentColor' : 'none' }}" stroke="{{ request()->routeIs('dashboard') ? 'none' : 'currentColor' }}" viewBox="0 0 24 24">
                    @if(request()->routeIs('dashboard'))
                        <path d="M11.47 3.84a.75.75 0 011.06 0l8.69 8.69a.75.75 0 101.06-1.06l-8.689-8.69a2.25 2.25 0 00-3.182 0l-8.69 8.69a.75.75 0 001.061 1.06l8.69-8.69z"/>
                        <path d="M12 5.432l8.159 8.159c.03.03.06.058.091.086v6.198c0 1.035-.84 1.875-1.875 1.875H15a.75.75 0 01-.75-.75v-4.5a.75.75 0 00-.75-.75h-3a.75.75 0 00-.75.75V21a.75.75 0 01-.75.75H5.625a1.875 1.875 0 01-1.875-1.875v-6.198a2.29 2.29 0 00.091-.086L12 5.43z"/>
                    @else
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"/>
                    @endif
                </svg>
                <span class="hidden lg:block font-{{ request()->routeIs('dashboard') ? 'bold' : 'semibold' }} text-sm">Beranda</span>
            </a>



            <!-- Explore -->
            <a href="{{ route('explore') }}"
               class="flex items-center justify-center lg:justify-start gap-4 p-2 md:px-3 md:py-3 rounded-xl transition group flex-1 md:flex-none
               {{ request()->routeIs('explore') ? 'bg-indigo-50 text-indigo-600 dark:bg-slate-800 dark:text-white' : 'text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:text-gray-400 dark:hover:bg-slate-800/60 dark:hover:text-slate-900 dark:text-white' }}">
                <svg class="w-6 h-6 md:w-6 md:h-6 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="{{ request()->routeIs('explore') ? '3' : '2' }}" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                </svg>
                <span class="hidden lg:block font-{{ request()->routeIs('explore') ? 'bold' : 'semibold' }} text-sm">Eksplorasi</span>
            </a>

            <!-- Map -->
            <a href="{{ route('photographers.map') }}"
               class="flex items-center justify-center lg:justify-start gap-4 p-2 md:px-3 md:py-3 rounded-xl transition group flex-1 md:flex-none
               {{ request()->routeIs('photographers.map') ? 'bg-indigo-50 text-indigo-600 dark:bg-slate-800 dark:text-white' : 'text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:text-gray-400 dark:hover:bg-slate-800/60 dark:hover:text-slate-900 dark:text-white' }}">
                <svg class="w-6 h-6 md:w-6 md:h-6 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
                <span class="hidden lg:block font-{{ request()->routeIs('photographers.map') ? 'bold' : 'semibold' }} text-sm">Peta Kreator</span>
            </a>

            <!-- Create Story / Upload (Mobile center button) -->
            @auth
            <button onclick="document.getElementById('story-modal').classList.remove('hidden')"
                    class="flex items-center justify-center lg:justify-start gap-4 p-2 md:px-3 md:py-3 rounded-xl transition group flex-1 md:flex-none md:w-full md:text-left text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:text-gray-400 dark:hover:bg-slate-800/60 dark:hover:text-slate-900 dark:text-white">
                <div class="w-8 h-8 md:w-6 md:h-6 rounded-lg md:rounded-lg border-2 border-current flex items-center justify-center flex-shrink-0">
                    <svg class="w-4 h-4 md:w-4 md:h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M12 4v16m8-8H4"/></svg>
                </div>
                <span class="hidden lg:block font-semibold text-sm">Buat Story</span>
            </button>

            <!-- Direct Messages (Desktop Only, mobile moved to top header) -->
            <a href="{{ route('messages.inbox') }}"
               class="hidden md:flex items-center justify-center lg:justify-start gap-4 px-3 py-3 rounded-xl transition group relative
               {{ request()->routeIs('messages.*') ? 'bg-indigo-50 text-indigo-600 dark:bg-slate-800 dark:text-white' : 'text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:text-gray-400 dark:hover:bg-slate-800/60 dark:hover:text-slate-900 dark:text-white' }}">
                <div class="relative flex-shrink-0">
                    <svg class="w-6 h-6" fill="{{ request()->routeIs('messages.*') ? 'currentColor' : 'none' }}" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="{{ request()->routeIs('messages.*') ? '0' : '2' }}" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
                    </svg>
                    @php $unread = Auth::user()->unreadMessageCount(); @endphp
                    @if($unread > 0)
                        <span class="absolute -top-1.5 -right-1.5 min-w-[16px] h-4 bg-red-500 text-slate-900 dark:text-white text-[9px] font-black rounded-full flex items-center justify-center px-0.5">
                            {{ $unread > 9 ? '9+' : $unread }}
                        </span>
                    @endif
                </div>
                <span class="hidden lg:block font-{{ request()->routeIs('messages.*') ? 'bold' : 'semibold' }} text-sm">
                    Pesan
                    @if($unread > 0)<span class="ml-1 text-xs font-black text-red-400">({{ $unread }})</span>@endif
                </span>
            </a>

            <!-- Cart -->
            <a href="{{ route('cart.index') }}"
               class="flex items-center justify-center lg:justify-start gap-4 p-2 md:px-3 md:py-3 rounded-xl transition group flex-1 md:flex-none
               {{ request()->routeIs('cart.index') ? 'bg-indigo-50 text-indigo-600 dark:bg-slate-800 dark:text-white' : 'text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:text-gray-400 dark:hover:bg-slate-800/60 dark:hover:text-slate-900 dark:text-white' }}">
                <div class="relative">
                    <svg class="w-6 h-6 md:w-6 md:h-6 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="{{ request()->routeIs('cart.index') ? '3' : '2' }}" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/>
                    </svg>
                </div>
                <span class="hidden lg:block font-semibold text-sm">Keranjang</span>
            </a>

            <!-- Top Up (Desktop only to save space on mobile) -->
            <a href="{{ route('payment.topup') }}"
               class="hidden md:flex items-center justify-center lg:justify-start gap-4 px-3 py-3 rounded-xl transition group
               {{ request()->routeIs('payment.topup') ? 'bg-emerald-50 text-emerald-600 dark:bg-slate-800 dark:text-emerald-400' : 'text-slate-500 hover:bg-slate-100 hover:text-emerald-600 dark:text-gray-400 dark:hover:bg-slate-800/60 dark:hover:text-emerald-400' }}">
                <svg class="w-6 h-6 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                <span class="hidden lg:block font-semibold text-sm">Top Up Saldo</span>
            </a>

            <!-- Photographer Dashboard (Desktop only icon on left menu) -->
            @if(Auth::user()->isPhotographer())
            <a href="{{ route('photographer.dashboard') }}"
               class="hidden md:flex items-center justify-center lg:justify-start gap-4 px-3 py-3 rounded-xl transition group
               {{ request()->routeIs('photographer.*') ? 'bg-indigo-100 text-indigo-600 border border-indigo-200 dark:bg-indigo-500/20 dark:text-indigo-300 dark:border-indigo-500/30' : 'text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:text-gray-400 dark:hover:bg-slate-800/60 dark:hover:text-slate-900 dark:text-white' }}">
                <svg class="w-6 h-6 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
                <span class="hidden lg:block font-semibold text-sm">Studio Saya</span>
            </a>
            @endif

            <!-- Admin Panel (Desktop only) -->
            @if(Auth::user()->isSuperadmin())
            <a href="{{ route('admin.dashboard') }}"
               class="hidden md:flex items-center justify-center lg:justify-start gap-4 px-3 py-3 rounded-xl transition group text-amber-600 hover:bg-amber-50 dark:text-amber-400 dark:hover:bg-amber-500/10">
                <svg class="w-6 h-6 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/>
                </svg>
                <span class="hidden lg:block font-semibold text-sm">Admin Panel</span>
            </a>
            @endif
            
            <!-- Theme Toggle -->
            <button onclick="toggleTheme()" class="flex items-center justify-center lg:justify-start gap-4 p-2 md:px-3 md:py-3 rounded-xl transition group flex-1 md:flex-none text-slate-500 hover:text-slate-900 hover:bg-slate-200 dark:text-gray-400 dark:hover:bg-slate-800/60 dark:hover:text-slate-900 dark:text-white w-full">
                <svg id="theme-icon-light" class="hidden dark:block w-6 h-6 md:w-6 md:h-6 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
                <svg id="theme-icon-dark" class="block dark:hidden w-6 h-6 md:w-6 md:h-6 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
                </svg>
                <span class="hidden lg:block font-semibold text-sm" id="theme-text">Tema Terang</span>
            </button>
            @endauth

            @guest
            <a href="{{ route('login') }}" class="flex md:hidden items-center justify-center gap-4 p-2 rounded-xl text-slate-500 dark:text-gray-400 hover:text-slate-900 dark:text-white transition flex-1">
                <svg class="w-6 h-6 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"/></svg>
            </a>
            <a href="{{ route('login') }}" class="hidden md:flex items-center justify-center lg:justify-start gap-4 px-3 py-3 rounded-xl text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:text-gray-400 dark:hover:bg-slate-800/60 dark:hover:text-slate-900 dark:text-white transition">
                <svg class="w-6 h-6 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1"/></svg>
                <span class="hidden lg:block font-semibold text-sm">Masuk</span>
            </a>
            @endguest

            <!-- Profile / Account Menu (Mobile icon) -->
            @auth
            <div x-data="{ open: false }" class="flex md:hidden relative items-center justify-center flex-1 h-full p-2">
                <button @click="open = !open" class="focus:outline-none flex items-center justify-center">
                    <img class="w-7 h-7 rounded-full object-cover ring-2 ring-indigo-500/40"
                         src="{{ Auth::user()->profile_photo_url }}" alt="">
                </button>
                <!-- Mobile Popup Menu -->
                <div x-show="open" @click.away="open = false" x-cloak
                     class="absolute bottom-16 right-2 w-48 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl shadow-2xl py-1 z-50">
                    <div class="px-4 py-2 border-b border-slate-700">
                        <p class="text-xs font-bold text-slate-500 dark:text-gray-400">{{ Auth::user()->name }}</p>
                    </div>
                    @if(Auth::user()->isPhotographer())
                    <a href="{{ route('photographer.dashboard') }}" class="block px-4 py-2 text-sm text-emerald-400 hover:bg-slate-100 dark:hover:bg-slate-700">Studio Saya</a>
                    @endif
                    <a href="{{ route('payment.topup') }}" class="block px-4 py-2 text-sm text-indigo-400 hover:bg-slate-100 dark:hover:bg-slate-700">Top Up Saldo</a>
                    <a href="{{ route('profile') }}" class="block px-4 py-2 text-sm text-slate-700 dark:text-gray-200 hover:bg-slate-100 dark:hover:bg-slate-700">Profil Saya</a>
                    <a href="{{ route('profile.edit') }}" class="block px-4 py-2 text-sm text-slate-700 dark:text-gray-200 hover:bg-slate-100 dark:hover:bg-slate-700">Edit Profil</a>
                    <form method="POST" action="{{ route('logout') }}" class="border-t border-slate-200 dark:border-slate-700 mt-1">
                        @csrf
                        <button type="submit" class="w-full text-left px-4 py-2 text-sm text-red-400 hover:bg-slate-100 dark:hover:bg-slate-700">Keluar</button>
                    </form>
                </div>
            </div>
            @endauth

        </nav>
    </div>

    <!-- Bottom: User Profile (Desktop Only) -->
    <div class="hidden md:block p-2 lg:p-3 mb-2 border-t border-slate-200 dark:border-slate-800">
        @auth
        <div x-data="{ open: false }" class="relative">
            <button @click="open = !open" class="w-full flex items-center justify-center lg:justify-start gap-3 p-2 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-50 dark:bg-slate-800 transition">
                <img class="w-9 h-9 rounded-full object-cover ring-2 ring-indigo-500/40 flex-shrink-0"
                     src="{{ Auth::user()->profile_photo_url }}" alt="">
                <div class="hidden lg:block text-left overflow-hidden">
                    <p class="text-sm font-bold text-slate-700 dark:text-gray-200 truncate">{{ Auth::user()->name }}</p>
                    <p class="text-xs text-slate-400 dark:text-gray-500 truncate">{{ Auth::user()->username ? '@'.Auth::user()->username : Auth::user()->email }}</p>
                </div>
            </button>

            <!-- Popup Menu -->
            <div x-show="open" @click.away="open = false" x-cloak
                 class="absolute bottom-14 left-0 w-52 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl shadow-2xl overflow-hidden py-1 z-[100]">
                <div class="px-4 py-2 border-b border-slate-700">
                    <p class="text-xs font-bold text-slate-500 dark:text-gray-400">Masuk sebagai</p>
                    <p class="text-sm font-semibold text-slate-900 dark:text-white truncate">{{ Auth::user()->name }}</p>
                </div>
                <a href="{{ route('profile') }}" class="flex items-center gap-3 px-4 py-2.5 text-sm text-slate-700 dark:text-gray-200 hover:bg-slate-100 dark:hover:bg-slate-700 transition">
                    <svg class="w-4 h-4 text-slate-500 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
                    Profil Saya
                </a>
                <a href="{{ route('profile.edit') }}" class="flex items-center gap-3 px-4 py-2.5 text-sm text-slate-700 dark:text-gray-200 hover:bg-slate-100 dark:hover:bg-slate-700 transition">
                    <svg class="w-4 h-4 text-slate-500 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                    Pengaturan Profil
                </a>
                <div class="border-t border-slate-200 dark:border-slate-700 mt-1 pt-1">
                    <form method="POST" action="{{ route('logout') }}">
                        @csrf
                        <button type="submit" class="w-full flex items-center gap-3 px-4 py-2.5 text-sm text-red-400 hover:bg-slate-100 dark:hover:bg-slate-700 transition">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/></svg>
                            Keluar
                        </button>
                    </form>
                </div>
            </div>
        </div>
        @endauth

        @guest
        <div class="flex flex-col gap-2 px-2">
            <a href="{{ route('register') }}" class="py-2 text-center text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-slate-900 dark:text-white rounded-xl transition">
                <span class="hidden lg:inline">Daftar Gratis</span>
                <span class="lg:hidden">+</span>
            </a>
        </div>
        @endguest
    </div>
</aside>

<!-- ─── STORY UPLOAD MODAL ────────────────────────────────────────────────── -->
@auth
<div id="story-modal" class="hidden fixed inset-0 z-[100] bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
    <div class="bg-white dark:bg-slate-900 border border-slate-700 rounded-3xl w-full max-w-sm shadow-2xl overflow-hidden">
        <!-- Modal Header -->
        <div class="flex items-center justify-between px-6 py-4 border-b border-slate-200 dark:border-slate-800">
            <h3 class="font-bold text-slate-900 dark:text-white">Buat Story Baru</h3>
            <button onclick="document.getElementById('story-modal').classList.add('hidden')" class="text-slate-500 dark:text-gray-400 hover:text-slate-900 dark:text-white transition">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
        </div>

        <!-- Upload Form -->
        <form action="{{ route('stories.store') }}" method="POST" enctype="multipart/form-data" class="p-6 space-y-4">
            @csrf

            <!-- File Drop Zone -->
            <label for="story-file-input" class="block cursor-pointer">
                <div id="story-dropzone" class="border-2 border-dashed border-slate-700 hover:border-indigo-500 rounded-2xl p-8 text-center transition-all">
                    <div id="story-preview-container" class="hidden">
                        <img id="story-img-preview" class="max-h-48 mx-auto rounded-xl object-cover">
                        <video id="story-vid-preview" class="max-h-48 mx-auto rounded-xl hidden" controls></video>
                    </div>
                    <div id="story-upload-icon">
                        <div class="w-14 h-14 mx-auto mb-3 bg-slate-50 dark:bg-slate-800 rounded-full flex items-center justify-center">
                            <svg class="w-7 h-7 text-slate-400 dark:text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"/></svg>
                        </div>
                        <p class="text-sm font-semibold text-slate-600 dark:text-gray-300">Klik atau seret file ke sini</p>
                        <p class="text-xs text-slate-400 dark:text-gray-500 mt-1">Foto (JPG, PNG) atau Video (MP4) • Maks 50MB</p>
                    </div>
                </div>
                <input id="story-file-input" type="file" name="file" class="hidden" accept="image/jpg,image/jpeg,image/png,image/gif,video/mp4,video/mov,video/webm" required onchange="previewStory(this)">
            </label>

            <!-- Caption -->
            <textarea name="caption" rows="2" maxlength="300" placeholder="Tambahkan keterangan (opsional)..."
                      class="w-full px-4 py-3 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl text-slate-700 dark:text-gray-200 placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 text-sm resize-none"></textarea>

            <p class="text-xs text-slate-400 dark:text-gray-500 text-center">Story akan menghilang secara otomatis setelah 24 jam.</p>

            <button type="submit" class="w-full py-3 bg-gradient-to-r from-indigo-600 to-pink-500 hover:from-indigo-500 hover:to-pink-400 text-slate-900 dark:text-white font-bold rounded-xl transition shadow-lg">
                Bagikan Story
            </button>
        </form>
    </div>
</div>

<script>
function previewStory(input) {
    const file = input.files[0];
    if (!file) return;
    const isVideo = file.type.startsWith('video/');
    const icon = document.getElementById('story-upload-icon');
    const preview = document.getElementById('story-preview-container');
    const img = document.getElementById('story-img-preview');
    const vid = document.getElementById('story-vid-preview');

    icon.classList.add('hidden');
    preview.classList.remove('hidden');

    if (isVideo) {
        vid.classList.remove('hidden');
        img.classList.add('hidden');
        vid.src = URL.createObjectURL(file);
    } else {
        img.classList.remove('hidden');
        vid.classList.add('hidden');
        img.src = URL.createObjectURL(file);
    }
}

function notificationDropdown() {
    return {
        open: false,
        notifications: [],
        unreadCount: 0,
        loading: false,

        init() {
            this.fetchData();
            // Polling every 30 seconds
            setInterval(() => this.fetchData(), 30000);
        },

        async fetchData() {
            try {
                const res = await fetch('{{ route("notifications.index") }}');
                if (res.ok) {
                    const data = await res.json();
                    this.notifications = data.notifications;
                    this.unreadCount = data.unreadCount;
                }
            } catch (err) {
                console.error('Failed to fetch notifications', err);
            }
        },

        async toggle() {
            this.open = !this.open;
            if (this.open) {
                this.loading = true;
                await this.fetchData();
                this.loading = false;
            }
        },

        async markAsRead(id, redirectUrl) {
            try {
                const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
                await fetch(`/notifications/${id}/read`, {
                    method: 'POST',
                    headers: {
                        'X-CSRF-TOKEN': token,
                        'Accept': 'application/json'
                    }
                });
            } catch (err) {
                console.error('Failed to mark notification as read', err);
            }
            window.location.href = redirectUrl;
        },

        async markAllAsRead() {
            try {
                const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
                await fetch('{{ route("notifications.read_all") }}', {
                    method: 'POST',
                    headers: {
                        'X-CSRF-TOKEN': token,
                        'Accept': 'application/json'
                    }
                });
                this.fetchData();
            } catch (err) {
                console.error('Failed to mark all as read', err);
            }
        }
    }
}

// Theme Toggle Logic
function toggleTheme() {
    const html = document.documentElement;
    const isDark = html.classList.contains('dark');
    
    if (isDark) {
        html.classList.remove('dark');
        localStorage.theme = 'light';
    } else {
        html.classList.add('dark');
        localStorage.theme = 'dark';
    }
    updateThemeUI();
}

function updateThemeUI() {
    const isDark = document.documentElement.classList.contains('dark');
    const themeText = document.getElementById('theme-text');
    if(themeText) {
        themeText.innerText = isDark ? 'Tema Terang' : 'Tema Gelap';
    }
}

// Init theme UI text on load
document.addEventListener('DOMContentLoaded', updateThemeUI);
</script>
@endauth