@extends('layouts.app')
@section('title', 'Keranjang Belanja - KREAVANA')

@section('content')
<div class="py-4">
    <h1 class="text-2xl font-extrabold text-gray-100 mb-8 flex items-center gap-2">
        <svg class="w-7 h-7 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"></path></svg>
        Keranjang Belanja
    </h1>

    @if(empty($photos) || $photos->isEmpty())
        <div class="text-center py-16 glass rounded-2xl border border-gray-900">
            <svg class="w-16 h-16 text-gray-600 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"></path></svg>
            <h3 class="text-lg font-bold text-gray-400">Keranjang Belanja Kosong</h3>
            <p class="text-sm text-gray-500 mt-1 mb-6">Anda belum memasukkan foto premium ke dalam keranjang.</p>
            <a href="{{ route('explore') }}" class="px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold shadow-md shadow-indigo-500/25 transition">
                Jelajahi Galeri Foto
            </a>
        </div>
    @else
        <div class="grid grid-cols-1 lg:grid-cols-12 gap-8">
            
            <!-- Left: List of Items (Col 8) -->
            <div class="lg:col-span-8 space-y-4">
                @foreach($photos as $photo)
                    <div class="glass rounded-xl p-4 border border-gray-900/60 flex items-center justify-between gap-4">
                        <div class="flex items-center gap-4">
                            <!-- Image Mini -->
                            <div class="w-16 h-16 rounded-lg overflow-hidden bg-gray-950 flex-shrink-0 border border-gray-900">
                                <img src="{{ asset('storage/' . $photo->watermarked_path) }}" alt="{{ $photo->title }}" class="w-full h-full object-cover">
                            </div>
                            <div>
                                <h3 class="text-sm font-bold text-gray-200 line-clamp-1">{{ $photo->title }}</h3>
                                <p class="text-[11px] text-gray-500 mt-0.5">Karya: {{ $photo->photographer->name }}</p>
                                <p class="text-xs font-bold text-indigo-400 mt-1">Rp {{ number_format($photo->price, 0, ',', '.') }}</p>
                            </div>
                        </div>

                        <!-- Remove Action -->
                        <form action="{{ route('cart.remove', $photo->id) }}" method="POST">
                            @csrf
                            <button type="submit" class="p-2 rounded-lg text-gray-500 hover:text-red-400 hover:bg-red-500/5 border border-transparent hover:border-red-500/10 transition" title="Hapus dari keranjang">
                                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                            </button>
                        </form>
                    </div>
                @endforeach

                <!-- Clear Cart Action -->
                <div class="flex justify-between items-center pt-2">
                    <a href="{{ route('explore') }}" class="text-xs font-bold text-indigo-400 hover:text-indigo-300 flex items-center gap-1 transition">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"></path></svg>
                        Lanjut Cari Foto
                    </a>
                    <form action="{{ route('cart.clear') }}" method="POST">
                        @csrf
                        <button type="submit" class="text-xs font-semibold text-gray-500 hover:text-red-400 transition">
                            Bersihkan Keranjang
                        </button>
                    </form>
                </div>
            </div>

            <!-- Right: Order Summary (Col 4) -->
            <div class="lg:col-span-4">
                <div class="glass rounded-xl p-6 border border-gray-900 shadow-xl space-y-6">
                    <h3 class="text-sm font-extrabold uppercase tracking-wider text-gray-300">Ringkasan Pesanan</h3>
                    
                    <div class="space-y-3.5 text-xs text-gray-400 border-b border-gray-900 pb-4">
                        <div class="flex justify-between">
                            <span>Subtotal ({{ $photos->count() }} item)</span>
                            <span class="font-bold text-gray-200">Rp {{ number_format($subtotal, 0, ',', '.') }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span>Biaya Admin</span>
                            <span class="font-bold text-gray-200">Rp {{ number_format($adminFee, 0, ',', '.') }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span>Metode Pembayaran</span>
                            <span class="font-bold text-emerald-400">Saldo KREAVANA</span>
                        </div>
                    </div>

                    @auth
                        @php 
                            $user = Auth::user(); 
                            $balance = $user->balance;
                        @endphp
                        
                        <div class="p-3.5 rounded-xl border border-gray-800 bg-gray-950/40 text-xs">
                            <div class="flex justify-between items-center">
                                <span class="text-gray-500 font-medium">Saldo Ledger Anda:</span>
                                <span class="font-bold text-emerald-400 text-sm">Rp {{ number_format($balance, 0, ',', '.') }}</span>
                            </div>
                            @if($balance < $total)
                                <p class="text-[10px] text-red-400 mt-2 font-medium">Saldo Anda kurang Rp {{ number_format($total - $balance, 0, ',', '.') }}. Lakukan top-up terlebih dahulu.</p>
                            @endif
                        </div>
                    @endauth

                    <div class="flex justify-between items-baseline">
                        <span class="text-sm font-bold text-gray-200">Total Harga:</span>
                        <span class="text-xl font-extrabold text-indigo-400">Rp {{ number_format($total, 0, ',', '.') }}</span>
                    </div>

                    <!-- Checkout Actions -->
                    <div>
                        @auth
                            @if($balance >= $total)
                                <!-- Balance is sufficient, checkout directly -->
                                <form action="{{ route('cart.checkout') }}" method="POST">
                                    @csrf
                                    <button type="submit" class="w-full py-3 px-4 rounded-xl text-xs font-extrabold bg-indigo-600 hover:bg-indigo-500 text-white shadow-lg shadow-indigo-500/25 transition-all text-center">
                                        Bayar & Dapatkan File Asli
                                    </button>
                                </form>
                            @else
                                <!-- Insufficient balance, redirect to topup -->
                                <a href="{{ route('payment.topup') }}" class="w-full py-3 px-4 rounded-xl text-xs font-extrabold bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-white shadow-lg shadow-emerald-500/20 text-center block transition-all">
                                    Top Up Saldo Sekarang
                                </a>
                            @endif
                        @else
                            <a href="{{ route('login') }}" class="w-full py-3 px-4 rounded-xl text-xs font-extrabold bg-indigo-600 hover:bg-indigo-500 text-white text-center block transition-all">
                                Masuk untuk Membayar
                            </a>
                        @endauth
                    </div>

                </div>
            </div>

        </div>
    @endif
</div>
@endsection
