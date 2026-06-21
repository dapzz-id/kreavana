<form action="{{ route('profile.request_photographer') }}" method="POST" enctype="multipart/form-data" class="space-y-4">
    @csrf
    
    <!-- KTP File -->
    <div>
        <label for="ktp" class="block text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-2">Unggah KTP (Gambar/PDF)</label>
        <div class="relative flex items-center justify-center border border-dashed border-gray-800 hover:border-indigo-500 rounded-xl p-3 bg-gray-950/40 cursor-pointer group">
            <input type="file" id="ktp" name="ktp" required accept="image/*,application/pdf" class="absolute inset-0 opacity-0 cursor-pointer" onchange="updateKtpLabel(this)">
            <div class="text-center">
                <svg class="w-6 h-6 text-gray-600 group-hover:text-indigo-400 mx-auto mb-1 transition" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V8a2 2 0 00-2-2h-5m-4 0V5a2 2 0 114 0v1m-4 0a2 2 0 104 0m-5 8a2 2 0 100-4 2 2 0 000 4zm5 3a3 3 0 01-3-3h6a3 3 0 01-3 3z"></path></svg>
                <span id="ktp-label" class="text-[9px] font-bold text-gray-400 block truncate max-w-[180px]">Pilih file KTP</span>
            </div>
        </div>
        @error('ktp')
            <p class="mt-1 text-[10px] text-red-400 font-medium">{{ $message }}</p>
        @enderror
    </div>

    <!-- NPWP File -->
    <div>
        <label for="npwp" class="block text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-2">Unggah NPWP (Gambar/PDF)</label>
        <div class="relative flex items-center justify-center border border-dashed border-gray-800 hover:border-indigo-500 rounded-xl p-3 bg-gray-950/40 cursor-pointer group">
            <input type="file" id="npwp" name="npwp" required accept="image/*,application/pdf" class="absolute inset-0 opacity-0 cursor-pointer" onchange="updateNpwpLabel(this)">
            <div class="text-center">
                <svg class="w-6 h-6 text-gray-600 group-hover:text-indigo-400 mx-auto mb-1 transition" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>
                <span id="npwp-label" class="text-[9px] font-bold text-gray-400 block truncate max-w-[180px]">Pilih file NPWP</span>
            </div>
        </div>
        @error('npwp')
            <p class="mt-1 text-[10px] text-red-400 font-medium">{{ $message }}</p>
        @enderror
    </div>

    <button type="submit" class="w-full py-2.5 px-4 rounded-xl text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white shadow shadow-indigo-500/25 transition">
        Kirim Berkas Pengajuan
    </button>
</form>

<script>
    function updateKtpLabel(input) {
        const file = input.files[0];
        const label = document.getElementById('ktp-label');
        if (file) {
            label.innerText = file.name;
        } else {
            label.innerText = "Pilih file KTP";
        }
    }

    function updateNpwpLabel(input) {
        const file = input.files[0];
        const label = document.getElementById('npwp-label');
        if (file) {
            label.innerText = file.name;
        } else {
            label.innerText = "Pilih file NPWP";
        }
    }
</script>
