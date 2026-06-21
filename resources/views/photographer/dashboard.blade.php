@extends('layouts.app')
@section('title', 'Dashboard Fotografer - KREAVANA')

@section('content')
<div class="py-4">
    
    <!-- Header & Quick Stats -->
    <div class="flex flex-col xl:flex-row justify-between items-start xl:items-center gap-6 mb-8">
        <div>
            <h1 class="text-3xl font-extrabold text-white flex items-center gap-3">
                <div class="w-10 h-10 rounded-xl bg-gradient-to-tr from-emerald-500 to-teal-400 flex items-center justify-center text-white shadow-lg shadow-emerald-500/20">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"></path></svg>
                </div>
                Creator Studio
            </h1>
            <p class="text-sm text-gray-400 mt-2">Kelola portofolio karya foto digital Anda dan pantau penjualan secara real-time.</p>
        </div>
        
        <!-- Big Number Stats -->
        <div class="flex flex-wrap items-center gap-3 w-full xl:w-auto">
            <div class="flex-1 xl:flex-none glass px-5 py-4 rounded-2xl border border-gray-800 flex flex-col items-center justify-center">
                <p class="text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-1">Karya Diunggah</p>
                <p class="text-3xl font-black text-white">{{ $uploadedCount }}</p>
            </div>
            <div class="flex-1 xl:flex-none glass px-5 py-4 rounded-2xl border border-gray-800 flex flex-col items-center justify-center">
                <p class="text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-1">Total Terjual</p>
                <p class="text-3xl font-black text-indigo-400">{{ $salesCount }}</p>
            </div>
            <div class="flex-full xl:flex-none glass px-6 py-4 rounded-2xl border border-emerald-500/30 bg-emerald-500/5 flex flex-col items-center justify-center">
                <p class="text-[10px] font-bold text-emerald-500/70 uppercase tracking-wider mb-1">Pendapatan Bersih</p>
                <p class="text-3xl font-black text-emerald-400 tracking-tight">Rp {{ number_format($totalEarnings, 0, ',', '.') }}</p>
            </div>
        </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-12 gap-8">
        
        <!-- Left: Upload Section (Col 4) -->
        <div class="lg:col-span-4">
            <div class="glass p-6 rounded-2xl border border-gray-900 shadow-xl space-y-6">
                <div>
                    <h3 class="text-sm font-bold text-gray-200">Unggah Karya Baru</h3>
                    <p class="text-xs text-gray-500 mt-1">Foto premium berbayar akan otomatis diberi watermark "kreavana".</p>
                </div>

                <form action="{{ route('photographer.upload') }}" method="POST" enctype="multipart/form-data" class="space-y-4">
                    @csrf
                    
                    <!-- Title -->
                    <div>
                        <label for="title" class="block text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-2">Judul Foto</label>
                        <input id="title" name="title" type="text" required placeholder="Contoh: Sunset di Pantai Kuta" value="{{ old('title') }}"
                               class="w-full px-4 py-2.5 bg-gray-900 border border-gray-800 rounded-xl text-xs text-gray-200 focus:outline-none focus:ring-1 focus:ring-indigo-500">
                    </div>

                    <!-- Description -->
                    <div>
                        <label for="description" class="block text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-2">Deskripsi Foto</label>
                        <textarea id="description" name="description" placeholder="Ceritakan latar belakang foto ini..." rows="3"
                                  class="w-full px-4 py-2.5 bg-gray-900 border border-gray-800 rounded-xl text-xs text-gray-200 focus:outline-none focus:ring-1 focus:ring-indigo-500">{{ old('description') }}</textarea>
                    </div>

                    <!-- Drag and Drop File input -->
                    <div>
                        <label for="photo" class="block text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-2">File Foto (Resolusi Tinggi)</label>
                        <div id="drag-drop-zone" class="relative flex flex-col items-center justify-center border-2 border-dashed border-gray-700 hover:border-indigo-500 rounded-2xl p-8 bg-gray-950/40 cursor-pointer group transition-all">
                            <input type="file" id="photo" name="photo" required accept="image/*" class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10" onchange="handleFileSelect(this)">
                            
                            <div id="upload-placeholder" class="text-center flex flex-col items-center">
                                <div class="w-16 h-16 rounded-full bg-indigo-500/10 flex items-center justify-center mb-4 group-hover:scale-110 transition-transform">
                                    <svg class="w-8 h-8 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"></path></svg>
                                </div>
                                <span class="text-sm font-bold text-gray-200">Tarik gambar ke sini</span>
                                <span class="text-xs text-gray-500 mt-1 block">atau klik untuk memilih dari komputer</span>
                                <span class="text-[10px] text-gray-600 mt-2 block font-medium">JPEG, PNG, WEBP (Maks. 5MB)</span>
                            </div>

                            <div id="upload-preview" class="hidden flex-col items-center w-full">
                                <img id="preview-image" src="" alt="Preview" class="max-h-40 rounded-lg shadow-md mb-3 border border-gray-800 object-cover">
                                <span id="file-name" class="text-xs font-bold text-indigo-400 truncate w-full text-center"></span>
                                <p class="text-[10px] text-gray-500 mt-1">Klik untuk mengganti gambar</p>
                            </div>
                        </div>
                    </div>

                    <!-- Tags -->
                    <div>
                        <label for="tags" class="block text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-2">Tag Pencarian (Dipisah Koma)</label>
                        <input id="tags" name="tags" type="text" placeholder="nature, sunset, beach" value="{{ old('tags') }}"
                               class="w-full px-4 py-2.5 bg-gray-900 border border-gray-800 rounded-xl text-xs text-gray-200 focus:outline-none focus:ring-1 focus:ring-indigo-500">
                    </div>

                    <!-- Sell Toggle -->
                    <div class="flex items-center justify-between p-3 rounded-xl border border-gray-850 bg-gray-950/40">
                        <div class="flex items-center">
                            <input type="checkbox" id="is_for_sale" name="is_for_sale" value="1" onchange="togglePriceField(this)"
                                   class="h-4.5 w-4.5 text-indigo-600 focus:ring-indigo-500 border-gray-800 rounded bg-gray-900">
                            <label for="is_for_sale" class="ml-2 block text-xs font-bold text-gray-300">
                                Jual Foto Ini
                            </label>
                        </div>
                        <span class="text-[9px] font-bold text-indigo-400 uppercase">Premium</span>
                    </div>

                    <!-- Price (Conditional) -->
                    <div id="price_field_container" class="hidden">
                        <label for="price" class="block text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-2">Harga Jual (Rupiah)</label>
                        <div class="relative">
                            <span class="absolute left-3.5 top-2.5 text-xs font-bold text-gray-500">Rp</span>
                            <input id="price" name="price" type="number" min="0" placeholder="Masukkan harga, misal: 25000"
                                   class="w-full pl-9 pr-4 py-2.5 bg-gray-900 border border-gray-800 rounded-xl text-xs text-gray-200 focus:outline-none focus:ring-1 focus:ring-indigo-500 font-bold">
                        </div>
                    </div>

                    <button type="submit" class="w-full py-2.5 px-4 rounded-xl text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white shadow shadow-indigo-500/25 transition">
                        Simpan & Publikasikan
                    </button>
                </form>
            </div>
        </div>

        <!-- Right: My Listings (Col 8) -->
        <div class="lg:col-span-8">
            <div class="glass p-6 rounded-2xl border border-gray-900 shadow-xl space-y-6">
                <div>
                    <h3 class="text-sm font-bold text-gray-200">Karya Foto Saya</h3>
                    <p class="text-xs text-gray-500 mt-1">Daftar portofolio foto yang sudah diunggah oleh Anda.</p>
                </div>

                @if($photos->isEmpty())
                    <div class="text-center py-16 border border-dashed border-gray-850 rounded-xl">
                        <p class="text-xs text-gray-500">Anda belum mengunggah foto apa pun. Silakan isi form di sebelah kiri.</p>
                    </div>
                @else
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                        @foreach($photos as $photo)
                            <div class="p-3.5 rounded-xl border border-gray-900 bg-gray-950/20 flex gap-4 items-center">
                                <!-- Image Preview -->
                                <div class="w-20 h-20 rounded-lg overflow-hidden bg-gray-950 border border-gray-900 flex-shrink-0">
                                    <img src="{{ asset('storage/' . $photo->watermarked_path) }}" alt="{{ $photo->title }}" class="w-full h-full object-cover">
                                </div>
                                <!-- Metadata -->
                                <div class="flex-grow min-w-0">
                                    <h4 class="text-xs font-bold text-gray-200 truncate">{{ $photo->title }}</h4>
                                    <p class="text-[9px] text-gray-500 line-clamp-1 mt-0.5">{{ $photo->description }}</p>
                                    <div class="flex items-center gap-2 mt-2">
                                        @if($photo->is_for_sale)
                                            <span class="px-2 py-0.5 rounded bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 text-[9px] font-bold">
                                                Rp {{ number_format($photo->price, 0, ',', '.') }}
                                            </span>
                                        @else
                                            <span class="px-2 py-0.5 rounded bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-[9px] font-bold">
                                                Gratis
                                            </span>
                                        @endif
                                        <span class="text-[9px] text-gray-500 flex items-center gap-0.5">
                                            <svg class="w-3.5 h-3.5 text-gray-600" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clip-rule="evenodd"></path></svg>
                                            {{ $photo->likes_count }} suka
                                        </span>
                                    </div>
                                </div>
                            </div>
                        @endforeach
                    </div>
                @endif
            </div>
        </div>

    </div>
</div>
@endsection

@section('scripts')
<script>
    // Drag and Drop Logic
    const dropZone = document.getElementById('drag-drop-zone');
    const fileInput = document.getElementById('photo');
    const placeholder = document.getElementById('upload-placeholder');
    const previewContainer = document.getElementById('upload-preview');
    const previewImage = document.getElementById('preview-image');
    const fileNameDisplay = document.getElementById('file-name');

    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        dropZone.addEventListener(eventName, preventDefaults, false);
    });

    function preventDefaults(e) {
        e.preventDefault();
        e.stopPropagation();
    }

    ['dragenter', 'dragover'].forEach(eventName => {
        dropZone.addEventListener(eventName, highlight, false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
        dropZone.addEventListener(eventName, unhighlight, false);
    });

    function highlight(e) {
        dropZone.classList.add('border-indigo-500', 'bg-indigo-500/5');
        dropZone.classList.remove('border-gray-700', 'bg-gray-950/40');
    }

    function unhighlight(e) {
        dropZone.classList.remove('border-indigo-500', 'bg-indigo-500/5');
        dropZone.classList.add('border-gray-700', 'bg-gray-950/40');
    }

    dropZone.addEventListener('drop', handleDrop, false);

    function handleDrop(e) {
        const dt = e.dataTransfer;
        const files = dt.files;
        if(files.length > 0) {
            fileInput.files = files;
            handleFileSelect(fileInput);
        }
    }

    function handleFileSelect(input) {
        const file = input.files[0];
        if (file) {
            fileNameDisplay.innerText = file.name;
            
            const reader = new FileReader();
            reader.onload = function(e) {
                previewImage.src = e.target.result;
                placeholder.classList.add('hidden');
                previewContainer.classList.remove('hidden');
                previewContainer.classList.add('flex');
            }
            reader.readAsDataURL(file);
        } else {
            placeholder.classList.remove('hidden');
            previewContainer.classList.add('hidden');
            previewContainer.classList.remove('flex');
        }
    }

    function togglePriceField(checkbox) {
        const container = document.getElementById('price_field_container');
        const priceInput = document.getElementById('price');
        
        if (checkbox.checked) {
            container.classList.remove('hidden');
            priceInput.setAttribute('required', 'true');
            // Add subtle animation
            container.classList.add('animate-fade-in');
        } else {
            container.classList.add('hidden');
            priceInput.removeAttribute('required');
            priceInput.value = '';
        }
    }
</script>
@endsection
