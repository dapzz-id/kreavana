@extends('layouts.app')
@section('title', 'Top Up Saldo - KREAVANA')

@section('content')
<div class="max-w-2xl mx-auto px-4 py-10">

    <!-- Header -->
    <div class="mb-8">
        <h1 class="text-2xl font-bold text-slate-900 dark:text-white flex items-center gap-3">
            <div class="w-10 h-10 bg-emerald-500/20 rounded-xl flex items-center justify-center">
                <svg class="w-5 h-5 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
            </div>
            Top Up Saldo
        </h1>
        <p class="text-slate-500 dark:text-gray-400 text-sm mt-1">Isi saldo dompet KREAVANA Anda untuk membeli foto secara instan.</p>
    </div>

    <!-- Flash Messages -->
    @if(session('success'))
        <div class="mb-6 p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-xl text-emerald-300 text-sm flex items-center gap-3">
            <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>
            {{ session('success') }}
        </div>
    @endif
    @if(session('error'))
        <div class="mb-6 p-4 bg-red-500/10 border border-red-500/30 rounded-xl text-red-300 text-sm">
            {{ session('error') }}
        </div>
    @endif

    <!-- Current Balance -->
    <div class="bg-gradient-to-br from-indigo-900/40 to-slate-800/60 rounded-2xl border border-indigo-500/20 p-6 mb-6 relative overflow-hidden">
        <div class="absolute -top-6 -right-6 w-32 h-32 bg-indigo-500/5 rounded-full blur-2xl"></div>
        <p class="text-xs font-bold text-slate-500 dark:text-gray-400 uppercase tracking-widest mb-1">Saldo Tersedia</p>
        <p class="text-4xl font-black text-white">Rp {{ number_format($balance, 0, ',', '.') }}</p>
        <div class="flex items-center gap-1.5 mt-3">
            <span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
            <p class="text-xs text-emerald-400 font-semibold">Ledger Terenkripsi · Aman & Terverifikasi</p>
        </div>
    </div>

    <!-- Top Up Form (Midtrans Snap) -->
    <div class="bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-2xl p-6 space-y-6">
        <h2 class="text-sm font-bold text-slate-700 dark:text-gray-300 uppercase tracking-wider">Pilih Nominal Top Up</h2>

        <!-- Quick Amount Buttons -->
        <div class="grid grid-cols-3 gap-3">
            @foreach([25000, 50000, 100000, 250000, 500000, 1000000] as $preset)
            <button type="button" onclick="setAmount({{ $preset }})"
                    class="preset-btn py-3 rounded-xl border border-slate-600 hover:border-indigo-500 bg-white dark:bg-slate-50 dark:bg-slate-900/60 hover:bg-indigo-500/10 text-slate-700 dark:text-gray-300 hover:text-white text-sm font-bold transition-all"
                    data-value="{{ $preset }}">
                Rp {{ number_format($preset, 0, ',', '.') }}
            </button>
            @endforeach
        </div>

        <!-- Custom Amount Input -->
        <div>
            <label class="block text-xs font-semibold text-slate-500 dark:text-gray-400 uppercase tracking-wider mb-2">Atau Masukkan Nominal Lain</label>
            <div class="relative">
                <span class="absolute inset-y-0 left-4 flex items-center text-slate-500 dark:text-gray-400 font-bold text-sm">Rp</span>
                <input type="number" id="amount-input" min="10000" step="1000"
                       class="w-full pl-12 pr-4 py-3.5 bg-slate-50 dark:bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-slate-900 dark:text-gray-200 font-bold text-base focus:outline-none focus:ring-2 focus:ring-indigo-500 transition"
                       placeholder="Minimum Rp 10.000">
            </div>
            <p class="text-xs text-gray-500 mt-1.5">Minimum top up: Rp 10.000</p>
        </div>

        <!-- Summary -->
        <div id="amount-summary" class="hidden p-4 bg-white dark:bg-slate-50 dark:bg-slate-900/60 rounded-xl border border-slate-200 dark:border-slate-700 space-y-2 text-sm">
            <div class="flex justify-between text-slate-500 dark:text-gray-400">
                <span>Nominal Top Up</span>
                <span id="summary-amount" class="font-bold text-slate-900 dark:text-white">Rp 0</span>
            </div>
            <div class="flex justify-between text-slate-500 dark:text-gray-400">
                <span>Biaya Layanan</span>
                <span class="text-emerald-400 font-semibold">Gratis</span>
            </div>
            <div class="border-t border-slate-700 pt-2 flex justify-between">
                <span class="font-bold text-slate-900 dark:text-white">Total Dibayar</span>
                <span id="summary-total" class="font-black text-indigo-400">Rp 0</span>
            </div>
        </div>

        <!-- Pay Button -->
        <button id="pay-button" onclick="startPayment()"
                class="w-full py-4 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 disabled:cursor-not-allowed text-white font-black rounded-xl transition shadow-2xl shadow-indigo-500/30 text-base flex items-center justify-center gap-3">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/></svg>
            Bayar dengan Midtrans
        </button>

        <!-- Payment Methods Info -->
        <div class="flex items-center justify-center gap-6 pt-2">
            <div class="flex items-center gap-2 text-xs text-gray-500">
                <svg class="w-4 h-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg>
                SSL Secured
            </div>
            <div class="flex items-center gap-2 text-xs text-gray-500">
                <span class="font-bold text-blue-400">QRIS</span>
                <span>·</span>
                <span class="font-bold text-orange-400">GoPay</span>
                <span>·</span>
                <span class="font-bold text-teal-400">OVO</span>
                <span>·</span>
                <span>VA Bank</span>
            </div>
        </div>
    </div>

    <!-- Ledger History -->
    @if(isset($ledger) && $ledger->count())
    <div class="mt-8 bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-2xl p-6">
        <h2 class="text-sm font-bold text-slate-700 dark:text-gray-300 uppercase tracking-wider mb-4">Riwayat Transaksi</h2>
        <div class="space-y-3">
            @foreach($ledger as $entry)
            <div class="flex justify-between items-center py-2 border-b border-slate-700/50 last:border-0">
                <div>
                    <p class="text-sm font-semibold text-slate-800 dark:text-gray-200">{{ $entry->type_label }}</p>
                    <p class="text-xs text-gray-500">{{ $entry->created_at->format('d M Y, H:i') }}</p>
                </div>
                <span class="font-bold {{ $entry->is_credit ? 'text-emerald-400' : 'text-red-400' }}">
                    {{ $entry->is_credit ? '+' : '-' }}Rp {{ number_format(abs($entry->display_amount), 0, ',', '.') }}
                </span>
            </div>
            @endforeach
        </div>
    </div>
    @endif

</div>
@endsection

@section('scripts')
{{-- Midtrans Snap JS — switches between sandbox/production based on env --}}
@if(env('MIDTRANS_IS_PRODUCTION', false))
<script src="https://app.midtrans.com/snap/snap.js" data-client-key="{{ env('MIDTRANS_CLIENT_KEY') }}"></script>
@else
<script src="https://app.sandbox.midtrans.com/snap/snap.js" data-client-key="{{ env('MIDTRANS_CLIENT_KEY') }}"></script>
@endif

<script>
let selectedAmount = 0;

function setAmount(val) {
    selectedAmount = val;
    document.getElementById('amount-input').value = val;
    updateSummary(val);

    // Highlight selected preset
    document.querySelectorAll('.preset-btn').forEach(btn => {
        btn.classList.toggle('border-indigo-500', parseInt(btn.dataset.value) === val);
        btn.classList.toggle('bg-indigo-500/10', parseInt(btn.dataset.value) === val);
        btn.classList.toggle('text-white', parseInt(btn.dataset.value) === val);
    });
}

document.getElementById('amount-input').addEventListener('input', function() {
    const val = parseInt(this.value) || 0;
    selectedAmount = val;
    updateSummary(val);
    document.querySelectorAll('.preset-btn').forEach(b => {
        b.classList.remove('border-indigo-500','bg-indigo-500/10','text-white');
    });
});

function updateSummary(amount) {
    const summary = document.getElementById('amount-summary');
    if (amount >= 10000) {
        summary.classList.remove('hidden');
        document.getElementById('summary-amount').textContent = 'Rp ' + amount.toLocaleString('id-ID');
        document.getElementById('summary-total').textContent = 'Rp ' + amount.toLocaleString('id-ID');
    } else {
        summary.classList.add('hidden');
    }
}

async function startPayment() {
    const amount = selectedAmount || parseInt(document.getElementById('amount-input').value) || 0;

    if (amount < 10000) {
        alert('Nominal minimum top up adalah Rp 10.000');
        return;
    }

    const btn = document.getElementById('pay-button');
    btn.disabled = true;
    btn.innerHTML = `<svg class="w-5 h-5 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg> Memproses...`;

    try {
        const res = await fetch('{{ route("payment.topup.process") }}', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
                'Accept': 'application/json',
            },
            body: JSON.stringify({ amount }),
        });

        const data = await res.json();

        if (!data.success) {
            throw new Error(data.message || 'Gagal mendapatkan token transaksi');
        }

        // Launch real Midtrans Snap popup
        snap.pay(data.snap_token, {
            onSuccess(result) {
                window.location.href = '{{ route("payment.topup") }}?status=success';
            },
            onPending(result) {
                window.location.href = '{{ route("payment.topup") }}?status=pending';
            },
            onError(result) {
                alert('Pembayaran gagal. Silakan coba lagi.');
            },
            onClose() {
                // User closed popup without finishing
            }
        });

    } catch (err) {
        alert(err.message || 'Terjadi kesalahan. Silakan coba lagi.');
    } finally {
        btn.disabled = false;
        btn.innerHTML = `<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/></svg> Bayar dengan Midtrans`;
    }
}
</script>
@endsection
