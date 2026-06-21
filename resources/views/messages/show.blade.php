@extends('layouts.app')
@section('title', 'Chat dengan {{ $partner->name }} - KREAVANA')

@section('styles')
<style>
.chat-bubble-mine { background: linear-gradient(135deg, #4f46e5, #7c3aed); border-radius: 1.25rem 1.25rem 0.25rem 1.25rem; }
.chat-bubble-theirs { background: #1e293b; border: 1px solid #334155; border-radius: 1.25rem 1.25rem 1.25rem 0.25rem; }
#messages-container { scroll-behavior: smooth; }
</style>
@endsection

@section('content')
<div class="flex flex-col h-[calc(100vh-0px)]" x-data="chatApp({{ $partner->id }}, {{ $messages->last()?->id ?? 0 }})" x-init="init()">

    <!-- Chat Header -->
    <div class="flex-shrink-0 bg-white/95 dark:bg-slate-50 dark:bg-slate-900/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800 px-4 py-3 flex items-center gap-4 sticky top-0 z-10">
        <a href="{{ route('messages.inbox') }}" class="text-slate-500 dark:text-gray-400 hover:text-white transition">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/></svg>
        </a>
        <div class="relative">
            <img src="{{ $partner->profile_photo_url }}" class="w-10 h-10 rounded-full object-cover">
        </div>
        <div class="flex-grow">
            <h2 class="font-bold text-slate-900 dark:text-white text-sm">{{ $partner->name }}</h2>
            <p class="text-xs text-slate-500 dark:text-gray-400">{{ $partner->username ? '@'.$partner->username : $partner->email }}</p>
        </div>
        <a href="{{ route('explore') }}" class="text-xs font-semibold text-indigo-400 hover:text-indigo-300 transition hidden md:block">
            Lihat Karya
        </a>
    </div>

    <!-- Messages Area -->
    <div id="messages-container" class="flex-grow overflow-y-auto px-4 py-6 space-y-4">
        @foreach($messages as $msg)
        @php $isMine = $msg->sender_id === Auth::id(); @endphp
        <div class="flex {{ $isMine ? 'justify-end' : 'justify-start' }} items-end gap-2" data-msg-id="{{ $msg->id }}">
            @if(!$isMine)
                <img src="{{ $partner->profile_photo_url }}" class="w-7 h-7 rounded-full object-cover flex-shrink-0 mb-1">
            @endif
            <div class="max-w-[75%] space-y-1">
                @if($msg->attachment_path)
                    <div class="{{ $isMine ? 'chat-bubble-mine' : 'chat-bubble-theirs' }} overflow-hidden p-1">
                        @if($msg->attachment_type === 'image')
                            <img src="{{ Storage::url($msg->attachment_path) }}" class="rounded-xl max-w-full" alt="Attachment">
                        @elseif($msg->attachment_type === 'video')
                            <video controls class="rounded-xl max-w-full"><source src="{{ Storage::url($msg->attachment_path) }}"></video>
                        @endif
                    </div>
                @endif
                @if($msg->body)
                    <div class="{{ $isMine ? 'chat-bubble-mine text-white' : 'chat-bubble-theirs text-slate-800 dark:text-gray-200' }} px-4 py-2.5 text-sm leading-relaxed">
                        {{ $msg->body }}
                    </div>
                @endif
                <p class="text-[10px] text-gray-500 px-1 {{ $isMine ? 'text-right' : 'text-left' }}">{{ $msg->created_at->format('H:i') }}</p>
            </div>
        </div>
        @endforeach

        <!-- Dynamic messages injected here -->
        <div id="new-messages-anchor"></div>
    </div>

    <!-- Input Bar -->
    <div class="flex-shrink-0 bg-white/95 dark:bg-slate-50 dark:bg-slate-900/95 backdrop-blur-md border-t border-slate-200 dark:border-slate-800 p-3">
        <form @submit.prevent="sendMessage()" class="flex items-center gap-3">
            <!-- Attachment -->
            <label class="p-2.5 text-slate-500 dark:text-gray-400 hover:text-indigo-400 cursor-pointer transition">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"/></svg>
                <input type="file" class="hidden" accept="image/*,video/*" @change="handleAttachment($event)">
            </label>

            <!-- Attachment Preview Badge -->
            <div x-show="attachment" x-cloak class="flex items-center gap-2 bg-indigo-500/20 border border-indigo-500/30 rounded-lg px-2 py-1">
                <span class="text-xs text-indigo-300" x-text="attachmentName"></span>
                <button type="button" @click="attachment=null;attachmentName=''" class="text-slate-500 dark:text-gray-400 hover:text-white">
                    <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/></svg>
                </button>
            </div>

            <!-- Text Input -->
            <input x-model="messageText" type="text" 
                   class="flex-grow bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-full px-4 py-2.5 text-sm text-slate-800 dark:text-gray-200 placeholder-gray-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 transition"
                   placeholder="Tulis pesan...">

            <!-- Send Button -->
            <button type="submit" :disabled="sending || (!messageText.trim() && !attachment)"
                    class="p-2.5 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 disabled:cursor-not-allowed text-white rounded-full transition shadow-lg shadow-indigo-500/20 flex-shrink-0">
                <svg x-show="!sending" class="w-5 h-5 translate-x-px -translate-y-px" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"/></svg>
                <svg x-show="sending" x-cloak class="w-5 h-5 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/></svg>
            </button>
        </form>
    </div>
</div>
@endsection

@section('scripts')
<script>
function chatApp(partnerId, lastMsgId) {
    return {
        messageText: '',
        sending: false,
        attachment: null,
        attachmentName: '',
        lastId: lastMsgId,
        pollInterval: null,

        init() {
            this.scrollToBottom();
            // Poll for new messages every 3 seconds
            this.pollInterval = setInterval(() => this.pollMessages(), 3000);
        },

        destroy() {
            clearInterval(this.pollInterval);
        },

        scrollToBottom() {
            this.$nextTick(() => {
                const c = document.getElementById('messages-container');
                if (c) c.scrollTop = c.scrollHeight;
            });
        },

        handleAttachment(event) {
            const file = event.target.files[0];
            if (!file) return;
            this.attachment = file;
            this.attachmentName = file.name.length > 20 ? file.name.substring(0, 20) + '...' : file.name;
        },

        async sendMessage() {
            if (this.sending || (!this.messageText.trim() && !this.attachment)) return;
            this.sending = true;

            const formData = new FormData();
            formData.append('_token', document.querySelector('meta[name="csrf-token"]').content);
            if (this.messageText.trim()) formData.append('body', this.messageText.trim());
            if (this.attachment) formData.append('attachment', this.attachment);

            try {
                const res = await fetch(`/messages/${partnerId}/send`, { method: 'POST', body: formData });
                const data = await res.json();

                if (data.success) {
                    this.appendMessage(data.message);
                    this.messageText = '';
                    this.attachment = null;
                    this.attachmentName = '';
                    this.lastId = data.message.id;
                }
            } catch (e) {
                console.error(e);
            }
            this.sending = false;
        },

        async pollMessages() {
            try {
                const res = await fetch(`/messages/${partnerId}/poll?since=${this.lastId}`);
                const data = await res.json();
                data.messages.forEach(msg => {
                    if (!document.querySelector(`[data-msg-id="${msg.id}"]`)) {
                        this.appendMessage(msg);
                        this.lastId = Math.max(this.lastId, msg.id);
                    }
                });
            } catch(e) {}
        },

        appendMessage(msg) {
            const anchor = document.getElementById('new-messages-anchor');
            const mine = msg.is_mine;
            const bubble = mine 
                ? `<div class="flex justify-end items-end gap-2" data-msg-id="${msg.id}">
                    <div class="max-w-[75%]">
                        <div class="chat-bubble-mine text-white px-4 py-2.5 text-sm">${msg.body || ''}</div>
                        <p class="text-[10px] text-gray-500 px-1 text-right">${msg.time}</p>
                    </div>
                  </div>`
                : `<div class="flex justify-start items-end gap-2" data-msg-id="${msg.id}">
                    <img src="${msg.sender_avatar}" class="w-7 h-7 rounded-full object-cover flex-shrink-0 mb-1">
                    <div class="max-w-[75%]">
                        <div class="chat-bubble-theirs text-slate-800 dark:text-gray-200 px-4 py-2.5 text-sm">${msg.body || ''}</div>
                        <p class="text-[10px] text-gray-500 px-1">${msg.time}</p>
                    </div>
                  </div>`;
            anchor.insertAdjacentHTML('beforebegin', bubble);
            this.scrollToBottom();
        },
    };
}
</script>
@endsection
