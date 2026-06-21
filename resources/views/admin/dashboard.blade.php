@extends('layouts.app')
@section('title', 'Admin Audit & Verifikasi - KREAVANA')

@section('content')
<div class="py-4">
    
    <!-- Title -->
    <div class="mb-8">
        <h1 class="text-2xl font-extrabold text-gray-100 flex items-center gap-2">
            <svg class="w-7 h-7 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path></svg>
            Superadmin Console
        </h1>
        <p class="text-xs text-gray-500 mt-1">Lakukan verifikasi identitas fotografer baru dan audit keamanan integritas sistem keuangan.</p>
    </div>

    <!-- Tab Buttons -->
    <div class="flex border-b border-gray-900 mb-6 gap-2">
        <button onclick="switchTab('verification')" id="tab-btn-verification" class="px-5 py-3 border-b-2 border-indigo-500 text-sm font-bold text-gray-100 focus:outline-none transition-colors">
            Pengajuan Verifikasi ({{ $requests->count() }})
        </button>
        <button onclick="switchTab('audit')" id="tab-btn-audit" class="px-5 py-3 border-b-2 border-transparent text-sm font-bold text-gray-400 hover:text-gray-200 focus:outline-none transition-colors">
            Audit Finansial Ledger
        </button>
    </div>

    <!-- Content Tabs -->
    <div>
        
        <!-- Tab 1: Verification Requests -->
        <div id="tab-verification" class="space-y-6">
            @if($requests->isEmpty())
                <div class="text-center py-16 glass rounded-2xl border border-gray-900">
                    <svg class="w-12 h-12 text-gray-600 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"></path></svg>
                    <p class="text-xs text-gray-500">Tidak ada pengajuan fotografer baru yang perlu ditinjau.</p>
                </div>
            @else
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    @foreach($requests as $req)
                        <div class="glass rounded-xl p-5 border border-gray-900 flex flex-col justify-between shadow-xl">
                            <div>
                                <div class="flex items-center justify-between pb-3 border-b border-gray-900/60 mb-4">
                                    <div class="flex items-center gap-2">
                                        <div class="w-8 h-8 rounded-full bg-indigo-500/10 flex items-center justify-center font-bold text-indigo-400 text-xs">
                                            {{ substr($req->user->name, 0, 2) }}
                                        </div>
                                        <div>
                                            <h4 class="text-xs font-bold text-gray-200">{{ $req->user->name }}</h4>
                                            <p class="text-[9px] text-gray-500">{{ $req->user->email }}</p>
                                        </div>
                                    </div>
                                    <span class="px-2 py-0.5 rounded bg-yellow-500/10 border border-yellow-500/20 text-yellow-500 text-[8px] font-bold uppercase tracking-wider">Menunggu</span>
                                </div>

                                <p class="text-[10px] text-gray-500 mb-3">Diajukan pada: {{ $req->created_at->format('d M Y, H:i') }}</p>

                                <!-- Documents Download Section -->
                                <div class="grid grid-cols-2 gap-3 mb-4">
                                    <a href="{{ route('admin.document', [$req->id, 'ktp']) }}" target="_blank" class="p-3 rounded-lg border border-gray-800 hover:border-indigo-500 bg-gray-950/40 hover:bg-indigo-950/5 transition flex flex-col items-center text-center">
                                        <svg class="w-5 h-5 text-gray-500 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V8a2 2 0 00-2-2h-5m-4 0V5a2 2 0 114 0v1m-4 0a2 2 0 104 0m-5 8a2 2 0 100-4 2 2 0 000 4zm5 3a3 3 0 01-3-3h6a3 3 0 01-3 3z"></path></svg>
                                        <span class="text-[10px] font-bold text-gray-300">Berkas KTP</span>
                                        <span class="text-[8px] text-gray-500 mt-0.5">Buka Dokumen</span>
                                    </a>
                                    <a href="{{ route('admin.document', [$req->id, 'npwp']) }}" target="_blank" class="p-3 rounded-lg border border-gray-800 hover:border-indigo-500 bg-gray-950/40 hover:bg-indigo-950/5 transition flex flex-col items-center text-center">
                                        <svg class="w-5 h-5 text-gray-500 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>
                                        <span class="text-[10px] font-bold text-gray-300">Berkas NPWP</span>
                                        <span class="text-[8px] text-gray-500 mt-0.5">Buka Dokumen</span>
                                    </a>
                                </div>
                            </div>

                            <!-- Actions -->
                            <div class="mt-4 pt-4 border-t border-gray-900/60 flex items-center gap-2">
                                <form action="{{ route('admin.approve', $req->id) }}" method="POST" class="flex-grow">
                                    @csrf
                                    <button type="submit" class="w-full py-2 rounded-lg text-[10px] font-bold bg-emerald-600 hover:bg-emerald-500 text-white shadow shadow-emerald-500/10 transition">
                                        Setujui Pengajuan
                                    </button>
                                </form>
                                
                                <button onclick="openRejectDialog({{ $req->id }}, '{{ $req->user->name }}')" class="py-2 px-4 rounded-lg text-[10px] font-bold border border-red-500/35 hover:border-red-500 text-red-400 hover:bg-red-500/5 transition">
                                    Tolak
                                </button>
                            </div>
                        </div>
                    @endforeach
                </div>
            @endif
        </div>

        <!-- Tab 2: Ledger Financial Security Audit -->
        <div id="tab-audit" class="hidden">
            <div class="glass rounded-xl border border-gray-900 overflow-hidden shadow-xl">
                <div class="p-5 border-b border-gray-900 bg-gray-950/40">
                    <h3 class="text-sm font-bold text-gray-200">Laporan Integritas Ledger Saldo</h3>
                    <p class="text-xs text-gray-500 mt-1">Memverifikasi tanda tangan HMAC dan rantai hash blockchain dari semua transaksi ledger saldo user.</p>
                </div>
                
                <div class="overflow-x-auto">
                    <table class="w-full text-left border-collapse text-xs">
                        <thead>
                            <tr class="bg-gray-950 text-gray-400 border-b border-gray-900 font-semibold">
                                <th class="p-4">User</th>
                                <th class="p-4">Email</th>
                                <th class="p-4">Peran (Role)</th>
                                <th class="p-4">Status Integritas</th>
                                <th class="p-4 text-right">Saldo Terverifikasi</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-900/40">
                            @foreach($auditReport as $report)
                                <tr class="hover:bg-gray-900/10 transition-colors">
                                    <td class="p-4 font-bold text-gray-200">{{ $report['name'] }}</td>
                                    <td class="p-4 text-gray-400">{{ $report['email'] }}</td>
                                    <td class="p-4 text-gray-400">
                                        @php $userObj = App\Models\User::find($report['user_id']); @endphp
                                        <span class="px-2 py-0.5 rounded bg-gray-900 border border-gray-800 text-[10px] font-medium">
                                            {{ $userObj && $userObj->role ? $userObj->role->name : 'Tanpa Role' }}
                                        </span>
                                    </td>
                                    <td class="p-4">
                                        @if($report['status'] === 'SECURE')
                                            <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-[10px] font-bold">
                                                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path></svg>
                                                Aman (Rantai Valid)
                                            </span>
                                        @else
                                            <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full bg-red-500/10 border border-red-500/20 text-red-400 text-[10px] font-bold" title="{{ $report['error'] }}">
                                                <svg class="w-3.5 h-3.5 animate-bounce" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg>
                                                MANIPULASI TERDETEKSI!
                                            </span>
                                        @endif
                                    </td>
                                    <td class="p-4 text-right font-black text-gray-100">
                                        @if($report['status'] === 'SECURE')
                                            Rp {{ number_format($report['balance'], 0, ',', '.') }}
                                        @else
                                            <span class="text-red-400">DIBLOKIR</span>
                                        @endif
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

    </div>
</div>

<!-- Rejection Reason Modal -->
<div id="rejectModal" class="fixed inset-0 z-50 hidden bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
    <div class="glass max-w-md w-full rounded-2xl overflow-hidden shadow-2xl border border-red-500/25">
        <div class="px-5 py-4 border-b border-gray-800 flex justify-between items-center bg-gray-950/60">
            <h3 class="text-sm font-bold text-gray-200">Tolak Permintaan Pengajuan</h3>
            <button type="button" onclick="closeRejectDialog()" class="text-gray-400 hover:text-white transition">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
            </button>
        </div>
        <form id="rejectForm" method="POST" class="p-5 space-y-4">
            @csrf
            <div>
                <p class="text-xs text-gray-400 mb-2">Tuliskan alasan penolakan berkas fotografer untuk user <strong id="reject-user-name" class="text-indigo-400"></strong>:</p>
                <textarea name="admin_notes" required placeholder="Contoh: Foto berkas KTP kurang jelas atau buram. Mohon unggah ulang..." rows="3"
                          class="w-full px-4 py-2.5 bg-gray-900 border border-gray-800 rounded-xl text-xs text-gray-200 focus:outline-none focus:ring-1 focus:ring-red-500"></textarea>
            </div>
            
            <div class="flex justify-end gap-3 pt-2">
                <button type="button" onclick="closeRejectDialog()" class="px-4 py-2 rounded-lg text-xs text-gray-400 hover:text-white">Batal</button>
                <button type="submit" class="px-5 py-2 rounded-lg text-xs bg-red-600 hover:bg-red-500 text-white font-bold transition">Tolak Pengajuan</button>
            </div>
        </form>
    </div>
</div>
@endsection

@section('scripts')
<script>
    // Tab switching logic
    function switchTab(tab) {
        const verifyBtn = document.getElementById('tab-btn-verification');
        const auditBtn = document.getElementById('tab-btn-audit');
        const verifySection = document.getElementById('tab-verification');
        const auditSection = document.getElementById('tab-audit');

        if (tab === 'verification') {
            verifyBtn.classList.add('border-indigo-500', 'text-gray-100');
            verifyBtn.classList.remove('border-transparent', 'text-gray-400');
            auditBtn.classList.add('border-transparent', 'text-gray-400');
            auditBtn.classList.remove('border-indigo-500', 'text-gray-100');
            
            verifySection.classList.remove('hidden');
            auditSection.classList.add('hidden');
        } else {
            auditBtn.classList.add('border-indigo-500', 'text-gray-100');
            auditBtn.classList.remove('border-transparent', 'text-gray-400');
            verifyBtn.classList.add('border-transparent', 'text-gray-400');
            verifyBtn.classList.remove('border-indigo-500', 'text-gray-100');
            
            auditSection.classList.remove('hidden');
            verifySection.classList.add('hidden');
        }
    }

    // Reject Dialog controls
    function openRejectDialog(requestId, userName) {
        const form = document.getElementById('rejectForm');
        form.action = `{{ route('admin.reject', '') }}/${requestId}`;
        
        document.getElementById('reject-user-name').innerText = userName;
        
        const modal = document.getElementById('rejectModal');
        modal.classList.remove('hidden');
        document.body.style.overflow = 'hidden';
    }

    function closeRejectDialog() {
        const modal = document.getElementById('rejectModal');
        modal.classList.add('hidden');
        document.body.style.overflow = '';
        document.getElementById('rejectForm').reset();
    }
</script>
@endsection
