@extends('layouts.app-fullwidth')
@section('title', 'KREAVANA - Platform Fotografi Premium & AI Marketplace')

@section('content')

{{-- ============================================================
     HERO
============================================================ --}}
<div class="ipp-hero">

    {{-- Noise texture overlay --}}
    <div class="ipp-noise" aria-hidden="true"></div>

    {{-- Ambient orbs --}}
    <div class="ipp-orb ipp-orb--indigo" aria-hidden="true"></div>
    <div class="ipp-orb ipp-orb--pink"   aria-hidden="true"></div>

    <div class="ipp-hero__inner">

        {{-- ── Left: Text ── --}}
        <div class="ipp-hero__text">

            <div class="ipp-badge">
                <span class="ipp-badge__dot"></span>
                Enterprise Ready
            </div>

            <h1 class="ipp-headline">
                Temukan &amp; Beli<br>
                <span class="ipp-headline__accent">Foto Premium</span>
            </h1>

            <p class="ipp-subhead">
                Marketplace fotografi dengan pencarian visual berbasis AI —
                temukan gambar sempurna hanya dengan mengunggah referensi Anda.
            </p>

            <div class="ipp-hero__cta">
                <a href="{{ route('explore') }}" class="ipp-btn ipp-btn--primary">
                    Jelajahi Galeri
                    <svg class="ipp-btn__icon" viewBox="0 0 20 20" fill="none" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 17l9-7-9-7v14z"/></svg>
                </a>
                @guest
                <a href="{{ route('register') }}" class="ipp-btn ipp-btn--ghost">
                    Gabung Sekarang
                </a>
                @endguest
            </div>

            <div class="ipp-stats">
                <div class="ipp-stat">
                    <span class="ipp-stat__num">50K+</span>
                    <span class="ipp-stat__label">Foto Tersedia</span>
                </div>
                <div class="ipp-stat__divider"></div>
                <div class="ipp-stat">
                    <span class="ipp-stat__num">12K+</span>
                    <span class="ipp-stat__label">Fotografer</span>
                </div>
                <div class="ipp-stat__divider"></div>
                <div class="ipp-stat">
                    <span class="ipp-stat__num">AES-256</span>
                    <span class="ipp-stat__label">Enkripsi</span>
                </div>
            </div>
        </div>

        {{-- ── Right: Film-frame graphic ── --}}
        <div class="ipp-hero__graphic" aria-hidden="true">

            {{-- Main frame --}}
            <div class="ipp-frame">
                {{-- Corner brackets --}}
                <span class="ipp-corner ipp-corner--tl"></span>
                <span class="ipp-corner ipp-corner--tr"></span>
                <span class="ipp-corner ipp-corner--bl"></span>
                <span class="ipp-corner ipp-corner--br"></span>

                {{-- Inner content --}}
                <div class="ipp-frame__inner">
                    <div class="ipp-grid-overlay"></div>
                    <svg class="ipp-camera-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.2"
                              d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86
                                 a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9
                                 a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"/>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.2"
                              d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"/>
                    </svg>
                    {{-- Scan line --}}
                    <div class="ipp-scanline"></div>
                    {{-- Film strip holes top --}}
                    <div class="ipp-strip ipp-strip--top">
                        @for ($i = 0; $i < 6; $i++)
                            <div class="ipp-hole"></div>
                        @endfor
                    </div>
                    <div class="ipp-strip ipp-strip--bottom">
                        @for ($i = 0; $i < 6; $i++)
                            <div class="ipp-hole"></div>
                        @endfor
                    </div>
                </div>
            </div>

            {{-- Floating badge: secure --}}
            <div class="ipp-badge-float ipp-badge-float--lock">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                          d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6
                             a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                </svg>
                <span>Terenkripsi</span>
            </div>

            {{-- Floating badge: AI --}}
            <div class="ipp-badge-float ipp-badge-float--ai">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                          d="M13 10V3L4 14h7v7l9-11h-7z"/>
                </svg>
                <span>AI Search</span>
            </div>

        </div>
    </div>
</div>

{{-- ============================================================
     FEATURES
============================================================ --}}
<div class="ipp-features">
    <div class="ipp-features__inner">

        <div class="ipp-section-label">Kenapa KREAVANA?</div>
        <h2 class="ipp-section-title">
            Infrastruktur enterprise.<br>
            Pengalaman kreator.
        </h2>

        <div class="ipp-cards">

            {{-- Card 1 --}}
            <div class="ipp-card ipp-card--indigo">
                <div class="ipp-card__num">01</div>
                <div class="ipp-card__icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                              d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944
                                 a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9
                                 c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622
                                 0-1.042-.133-2.052-.382-3.016z"/>
                    </svg>
                </div>
                <h3 class="ipp-card__title">Keamanan Setingkat Bank</h3>
                <p class="ipp-card__body">
                    Setiap transaksi dilindungi kriptografi Ledger AES-256 dan validasi
                    HMAC-SHA256 berantai — tidak ada manipulasi data yang bisa lolos.
                </p>
            </div>

            {{-- Card 2 --}}
            <div class="ipp-card ipp-card--pink ipp-card--featured">
                <div class="ipp-card__num">02</div>
                <div class="ipp-card__icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                              d="M13 10V3L4 14h7v7l9-11h-7z"/>
                    </svg>
                </div>
                <h3 class="ipp-card__title">Pencarian Visual Pintar</h3>
                <p class="ipp-card__body">
                    Unggah gambar referensi, biarkan AI mengekstrak konteks visual,
                    dan temukan foto yang benar-benar relevan — bukan sekadar tag.
                </p>
            </div>

            {{-- Card 3 --}}
            <div class="ipp-card ipp-card--purple">
                <div class="ipp-card__num">03</div>
                <div class="ipp-card__icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.8"
                              d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2
                                 m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6
                                 a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z"/>
                    </svg>
                </div>
                <h3 class="ipp-card__title">Integrasi Payment Gateway</h3>
                <p class="ipp-card__body">
                    Checkout instan via Midtrans — transfer bank, dompet digital,
                    kartu kredit, semua tersedia dalam satu alur yang mulus.
                </p>
            </div>

        </div>
    </div>
</div>

{{-- ============================================================
     STYLES
============================================================ --}}
<style>
/* ─── Reset & base ─────────────────────────────────────────── */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

/* ─── Design tokens ─────────────────────────────────────────── */
:root {
    --ipp-bg:          #07070D;
    --ipp-surface:     #0F0F1A;
    --ipp-border:      rgba(255,255,255,0.08);
    --ipp-border-hi:   rgba(255,255,255,0.14);
    --ipp-text:        #F0EDFF;
    --ipp-muted:       rgba(240,237,255,0.45);
    --ipp-indigo:      #6366F1;
    --ipp-indigo-dim:  rgba(99,102,241,0.12);
    --ipp-indigo-glow: rgba(99,102,241,0.35);
    --ipp-pink:        #EC4899;
    --ipp-pink-dim:    rgba(236,72,153,0.12);
    --ipp-pink-glow:   rgba(236,72,153,0.35);
    --ipp-purple:      #A855F7;
    --ipp-purple-dim:  rgba(168,85,247,0.12);
    --ipp-scan:        rgba(99,102,241,0.6);
    --ipp-r:           12px;
}

/* ─── HERO ──────────────────────────────────────────────────── */
.ipp-hero {
    position: relative;
    background: var(--ipp-bg);
    overflow: hidden;
    margin: -1.5rem -1rem 0;  /* bleed under nav */
    padding: 6rem 1rem 5rem;
}

/* noise */
.ipp-noise {
    position: absolute;
    inset: 0;
    background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.75' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='1'/%3E%3C/svg%3E");
    opacity: 0.035;
    pointer-events: none;
    z-index: 0;
}

/* orbs */
.ipp-orb {
    position: absolute;
    border-radius: 50%;
    filter: blur(110px);
    pointer-events: none;
    z-index: 0;
}
.ipp-orb--indigo {
    width: 520px; height: 520px;
    top: -140px; right: -120px;
    background: var(--ipp-indigo);
    opacity: .18;
}
.ipp-orb--pink {
    width: 400px; height: 400px;
    bottom: -120px; left: -100px;
    background: var(--ipp-pink);
    opacity: .14;
}

/* inner layout */
.ipp-hero__inner {
    position: relative;
    z-index: 1;
    max-width: 1120px;
    margin: 0 auto;
    display: flex;
    align-items: center;
    gap: 4rem;
}
.ipp-hero__text   { flex: 1; min-width: 0; }
.ipp-hero__graphic{ flex: 0 0 420px; display: none; }
@media (min-width: 900px) { .ipp-hero__graphic { display: block; } }

/* badge */
.ipp-badge {
    display: inline-flex;
    align-items: center;
    gap: .5rem;
    padding: .35rem .9rem;
    border-radius: 999px;
    border: 1px solid rgba(99,102,241,.3);
    background: rgba(99,102,241,.08);
    font-size: .7rem;
    font-weight: 700;
    letter-spacing: .12em;
    text-transform: uppercase;
    color: #a5b4fc;
    margin-bottom: 1.75rem;
}
.ipp-badge__dot {
    width: 6px; height: 6px;
    border-radius: 50%;
    background: var(--ipp-indigo);
    animation: blink 2s ease-in-out infinite;
}
@keyframes blink { 0%,100%{opacity:1} 50%{opacity:.3} }

/* headline */
.ipp-headline {
    font-size: clamp(2.4rem, 5.5vw, 4.2rem);
    font-weight: 900;
    line-height: 1.06;
    letter-spacing: -.03em;
    color: var(--ipp-text);
    margin-bottom: 1.5rem;
}
.ipp-headline__accent {
    background: linear-gradient(135deg, #818cf8 0%, #a78bfa 45%, #f472b6 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
}

/* subhead */
.ipp-subhead {
    font-size: 1.05rem;
    line-height: 1.7;
    color: var(--ipp-muted);
    max-width: 520px;
    margin-bottom: 2.25rem;
}

/* CTA buttons */
.ipp-hero__cta {
    display: flex;
    flex-wrap: wrap;
    gap: .75rem;
    margin-bottom: 2.75rem;
}
.ipp-btn {
    display: inline-flex;
    align-items: center;
    gap: .5rem;
    padding: .85rem 1.75rem;
    border-radius: var(--ipp-r);
    font-size: .95rem;
    font-weight: 700;
    text-decoration: none;
    transition: transform .2s, box-shadow .2s, background .2s;
    cursor: pointer;
    border: none;
}
.ipp-btn--primary {
    background: var(--ipp-indigo);
    color: #fff;
    box-shadow: 0 0 28px var(--ipp-indigo-glow);
}
.ipp-btn--primary:hover {
    background: #818cf8;
    box-shadow: 0 0 40px var(--ipp-indigo-glow);
    transform: translateY(-2px);
}
.ipp-btn--ghost {
    background: var(--ipp-border);
    color: var(--ipp-text);
    border: 1px solid var(--ipp-border-hi);
}
.ipp-btn--ghost:hover {
    background: rgba(255,255,255,.1);
    transform: translateY(-2px);
}
.ipp-btn__icon { width: 16px; height: 16px; }

/* stats */
.ipp-stats {
    display: flex;
    align-items: center;
    gap: 1.5rem;
    flex-wrap: wrap;
}
.ipp-stat { display: flex; flex-direction: column; gap: .2rem; }
.ipp-stat__num   { font-size: 1.3rem; font-weight: 800; color: var(--ipp-text); letter-spacing: -.02em; }
.ipp-stat__label { font-size: .72rem; color: var(--ipp-muted); letter-spacing: .04em; }
.ipp-stat__divider { width: 1px; height: 32px; background: var(--ipp-border-hi); }

/* ─── Film-frame graphic ──────────────────────────────────── */
.ipp-frame {
    position: relative;
    aspect-ratio: 1;
    border-radius: 1.5rem;
    border: 1px solid var(--ipp-border-hi);
    background: var(--ipp-surface);
    overflow: hidden;
}
/* corner brackets */
.ipp-corner {
    position: absolute;
    width: 22px; height: 22px;
    border-color: var(--ipp-indigo);
    border-style: solid;
    z-index: 3;
}
.ipp-corner--tl { top: 10px; left: 10px;  border-width: 2px 0 0 2px; border-radius: 4px 0 0 0; }
.ipp-corner--tr { top: 10px; right: 10px; border-width: 2px 2px 0 0; border-radius: 0 4px 0 0; }
.ipp-corner--bl { bottom: 10px; left: 10px;  border-width: 0 0 2px 2px; border-radius: 0 0 0 4px; }
.ipp-corner--br { bottom: 10px; right: 10px; border-width: 0 2px 2px 0; border-radius: 0 0 4px 0; }

.ipp-frame__inner {
    position: relative;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
}
.ipp-grid-overlay {
    position: absolute;
    inset: 0;
    background-image:
        linear-gradient(rgba(255,255,255,.025) 1px, transparent 1px),
        linear-gradient(90deg, rgba(255,255,255,.025) 1px, transparent 1px);
    background-size: 24px 24px;
}
.ipp-camera-icon {
    width: 96px; height: 96px;
    color: var(--ipp-indigo);
    opacity: .85;
    position: relative;
    z-index: 2;
    filter: drop-shadow(0 0 20px var(--ipp-indigo-glow));
}
.ipp-scanline {
    position: absolute;
    left: 0; right: 0; height: 2px;
    background: linear-gradient(90deg, transparent, var(--ipp-scan), transparent);
    box-shadow: 0 0 18px 4px var(--ipp-indigo-glow);
    animation: scan 3.5s ease-in-out infinite;
    z-index: 4;
}
@keyframes scan {
    0%   { top: 5%;  opacity: 0; }
    8%   { opacity: 1; }
    92%  { opacity: 1; }
    100% { top: 95%; opacity: 0; }
}

/* film strip */
.ipp-strip {
    position: absolute;
    left: 0; right: 0;
    display: flex;
    justify-content: space-evenly;
    z-index: 3;
}
.ipp-strip--top    { top: 0;    padding: 4px 6px; }
.ipp-strip--bottom { bottom: 0; padding: 4px 6px; }
.ipp-hole {
    width: 10px; height: 10px;
    border-radius: 3px;
    background: var(--ipp-bg);
    border: 1px solid var(--ipp-border-hi);
}

/* floating badges */
.ipp-badge-float {
    position: absolute;
    display: flex;
    align-items: center;
    gap: .5rem;
    padding: .55rem 1rem;
    border-radius: 999px;
    border: 1px solid var(--ipp-border-hi);
    background: rgba(15,15,26,.85);
    backdrop-filter: blur(12px);
    font-size: .75rem;
    font-weight: 600;
    color: var(--ipp-text);
    white-space: nowrap;
}
.ipp-badge-float svg { width: 14px; height: 14px; }
.ipp-badge-float--lock {
    bottom: -16px; left: -28px;
    color: #34d399;
}
.ipp-badge-float--lock svg { color: #34d399; }
.ipp-badge-float--ai {
    top: -16px; right: -20px;
    color: #f472b6;
}
.ipp-badge-float--ai svg { color: #f472b6; }

/* ─── FEATURES ──────────────────────────────────────────────── */
.ipp-features {
    background: var(--ipp-bg);
    padding: 6rem 1rem 7rem;
    margin: 0 -1rem;
}
.ipp-features__inner {
    max-width: 1120px;
    margin: 0 auto;
}

/* section label */
.ipp-section-label {
    font-size: .7rem;
    font-weight: 700;
    letter-spacing: .16em;
    text-transform: uppercase;
    color: var(--ipp-indigo);
    margin-bottom: 1rem;
}
.ipp-section-title {
    font-size: clamp(1.7rem, 3.5vw, 2.7rem);
    font-weight: 800;
    line-height: 1.15;
    letter-spacing: -.025em;
    color: var(--ipp-text);
    margin-bottom: 3.5rem;
}

/* cards */
.ipp-cards {
    display: grid;
    grid-template-columns: 1fr;
    gap: 1.25rem;
}
@media (min-width: 720px) {
    .ipp-cards { grid-template-columns: repeat(3, 1fr); }
}

.ipp-card {
    position: relative;
    padding: 2.25rem 2rem;
    border-radius: 1.5rem;
    border: 1px solid var(--ipp-border);
    background: var(--ipp-surface);
    overflow: hidden;
    transition: border-color .25s, transform .25s;
}
.ipp-card:hover { transform: translateY(-4px); }
.ipp-card--indigo:hover { border-color: rgba(99,102,241,.4); }
.ipp-card--pink:hover   { border-color: rgba(236,72,153,.4); }
.ipp-card--purple:hover { border-color: rgba(168,85,247,.4); }

/* featured card subtle glow bg */
.ipp-card--featured::before {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(135deg, var(--ipp-pink-dim) 0%, transparent 60%);
    pointer-events: none;
}

/* card number watermark */
.ipp-card__num {
    position: absolute;
    top: 1.5rem; right: 1.75rem;
    font-size: 3.5rem;
    font-weight: 900;
    letter-spacing: -.04em;
    opacity: .06;
    color: var(--ipp-text);
    line-height: 1;
    pointer-events: none;
    user-select: none;
}

/* icon */
.ipp-card__icon {
    width: 48px; height: 48px;
    border-radius: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 1.5rem;
    position: relative;
    z-index: 1;
}
.ipp-card__icon svg { width: 22px; height: 22px; }
.ipp-card--indigo .ipp-card__icon { background: var(--ipp-indigo-dim); color: #818cf8; }
.ipp-card--pink   .ipp-card__icon { background: var(--ipp-pink-dim);   color: #f472b6; }
.ipp-card--purple .ipp-card__icon { background: var(--ipp-purple-dim); color: #c084fc; }

.ipp-card__title {
    font-size: 1.05rem;
    font-weight: 700;
    color: var(--ipp-text);
    margin-bottom: .75rem;
    position: relative;
    z-index: 1;
}
.ipp-card__body {
    font-size: .875rem;
    line-height: 1.7;
    color: var(--ipp-muted);
    position: relative;
    z-index: 1;
}

/* ─── Responsive tweaks ─────────────────────────────────────── */
@media (max-width: 640px) {
    .ipp-hero { padding: 4rem 1rem 3.5rem; }
    .ipp-subhead { font-size: .95rem; }
    .ipp-stats { gap: 1rem; }
    .ipp-stat__num { font-size: 1.1rem; }
}

@media (prefers-reduced-motion: reduce) {
    .ipp-scanline, .ipp-badge__dot { animation: none; }
}
</style>
@endsection