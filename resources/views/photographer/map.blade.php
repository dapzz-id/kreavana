@extends('layouts.app')
@section('title', 'Peta Fotografer - KREAVANA')

@section('styles')
<!-- Leaflet CSS -->
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="" />
<style>
    #map {
        height: 600px;
        border-radius: 1.5rem;
        z-index: 1;
    }
    /* Customize leaflet styles to fit dark mode */
    .leaflet-container {
        background: #0f172a;
        font-family: inherit;
    }
    .leaflet-popup-content-wrapper, .leaflet-popup-tip {
        background: rgba(15, 23, 42, 0.95) !important;
        color: #f8fafc !important;
        border: 1px solid rgba(255, 255, 255, 0.1) !important;
        backdrop-filter: blur(12px) !important;
        border-radius: 1rem !important;
        box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.5) !important;
    }
    .leaflet-popup-close-button {
        color: #94a3b8 !important;
    }
</style>
@endsection

@section('content')
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
    <!-- Header -->
    <div class="mb-8 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
            <h1 class="text-3xl md:text-5xl font-black text-white tracking-tight">Eksplorasi Peta Kreator</h1>
            <p class="text-gray-400 text-sm md:text-base mt-2">Temukan fotografer dan videografer profesional di sekitar lokasi Anda.</p>
        </div>
        <div>
            <button onclick="zoomToUserLocation()" class="px-5 py-3 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-xl text-sm transition shadow-lg shadow-indigo-500/20 flex items-center gap-2">
                <svg class="w-5 h-5 animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
                Cari di Sekitar Saya
            </button>
        </div>
    </div>

    <!-- Map Container -->
    <div class="glass border border-slate-800 p-4 rounded-3xl shadow-2xl relative overflow-hidden">
        <div id="map" class="w-full"></div>
    </div>
</div>
@endsection

@section('scripts')
<!-- Leaflet JS -->
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js" integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
<script>
    // Inisialisasi Peta (Default koordinat Indonesia tengah: Jakarta)
    const map = L.map('map').setView([-6.2088, 106.8456], 11);

    // Dark Matter Tile Layer (CartoDB)
    L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
        subdomains: 'abcd',
        maxZoom: 20
    }).addTo(map);

    // Ambil data fotografer dari backend blade PHP
    const photographers = @json($photographers);
    
    // Custom Icon untuk Fotografer (Indigo-Pink Map Pin)
    const photographerIcon = L.divIcon({
        html: `<div class="w-8 h-8 rounded-full bg-gradient-to-tr from-indigo-500 to-pink-500 border-2 border-white flex items-center justify-center text-white shadow-xl shadow-indigo-500/50">
                <svg class="w-4.5 h-4.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
               </div>`,
        className: '',
        iconSize: [32, 32],
        iconAnchor: [16, 32],
        popupAnchor: [0, -32]
    });

    // Loop through photographers data and place markers
    const bounds = [];
    photographers.forEach(p => {
        if (p.latitude && p.longitude) {
            const marker = L.marker([p.latitude, p.longitude], { icon: photographerIcon }).addTo(map);
            
            // Popup HTML Card Design
            const popupHtml = `
                <div class="p-2 w-64 text-left font-sans">
                    <div class="flex items-center gap-3 mb-3">
                        <img class="w-10 h-10 rounded-full object-cover ring-2 ring-indigo-500/40" src="${p.profile_photo_url}" alt="${p.name}">
                        <div>
                            <h4 class="text-sm font-black text-white leading-tight">${p.name}</h4>
                            <span class="text-[10px] font-bold text-indigo-400 uppercase tracking-wider">Kreator KREAVANA</span>
                        </div>
                    </div>
                    <p class="text-xs text-gray-400 line-clamp-2 mb-3 leading-relaxed">${p.bio}</p>
                    <div class="flex items-center justify-between border-t border-slate-800/80 pt-2.5 mt-2">
                        <a href="${p.explore_url}" class="text-xs font-bold text-white bg-indigo-600 hover:bg-indigo-500 px-3.5 py-1.5 rounded-lg transition-colors flex items-center gap-1 shadow-lg shadow-indigo-500/20">
                            Lihat Karya
                            <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 5l7 7-7 7"/></svg>
                        </a>
                    </div>
                </div>
            `;
            
            marker.bindPopup(popupHtml);
            bounds.push([p.latitude, p.longitude]);
        }
    });

    // Auto-fit map boundaries to include all photographer markers
    if (bounds.length > 0) {
        map.fitBounds(bounds, { padding: [50, 50] });
    }

    // Geolocation user function
    function zoomToUserLocation() {
        if (!navigator.geolocation) {
            alert("Geolocation tidak didukung oleh browser Anda.");
            return;
        }

        navigator.geolocation.getCurrentPosition(
            (position) => {
                const userLat = position.coords.latitude;
                const userLng = position.coords.longitude;
                
                // Add marker for user
                const userIcon = L.divIcon({
                    html: `<div class="relative flex h-5 w-5">
                            <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-sky-400 opacity-75"></span>
                            <span class="relative inline-flex rounded-full h-5 w-5 bg-sky-500 border-2 border-white shadow-md"></span>
                           </div>`,
                    className: '',
                    iconSize: [20, 20],
                    iconAnchor: [10, 10]
                });
                
                L.marker([userLat, userLng], { icon: userIcon }).addTo(map).bindPopup("<div class='text-xs font-bold text-white px-1 py-0.5'>Lokasi Anda</div>").openPopup();
                map.setView([userLat, userLng], 13);
            },
            (error) => {
                alert("Gagal mendeteksi lokasi Anda: " + error.message);
            }
        );
    }
</script>
@endsection
