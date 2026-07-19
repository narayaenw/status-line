# Changelog

Formát vychází z [Keep a Changelog](https://keepachangelog.com/), verze podle [SemVer](https://semver.org/). Ke každé verzi existuje git tag `vX.Y.Z` a [GitHub Release](https://github.com/faborsky/claude-code-statusline/releases) — dej repu **Watch → Custom → Releases** a o nových verzích se dozvíš notifikací.

## [1.2.0] — 2026-07-09 — Zjednodušení: labely Context/Limits, bez ceny a času ✂️

- **Vypnuté segmenty ceny session (`$`) a délky (`🕐`)** — méně vizuálního šumu; řádek teď nese jen to, podle čeho se reálně rozhoduješ.
- **Šedé labely `Context:` / `Limits:`** — metriky jsou samovysvětlující i pro někoho, kdo statusline vidí poprvé.
- Čistý bash místo `seq`, nezávislost na jazyku systému (git přes plumbing), ošetřená přenositelnost.
- README: nový layout, cross-platform instalace (macOS / Linux / Windows přes Git Bash), reálná raw URL, nový screenshot.

## [1.1.0] — 2026-07-09 — Čerpání limitů předplatného ⏳

- **Nový segment `⏳ 5h:38% · 7d:72%`** — čerpání pětihodinového okna a týdenního stropu předplatného, čtené z `rate_limits` v payloadu Claude Code. Konečně vidíš, kolik ti zbývá, přímo ve status line.
- Segment se **sám skryje**, když payload pole nemá (Console API klíč, nebo před první odpovědí API) — nic nerozbije.
- Barevné prahy stejné jako u kontextu: 🟢 < 50 % → 🟡 → 🟠 → 🔴 ≥ 90 %.

## [1.0.0] — 2026-06-18 — První verze 🎉

Jeden bash skript (jediná závislost `jq`), který do status line Claude Code dá:

- **model + reasoning effort** (`[Opus 4.8 (1M context) ·xhigh]`),
- **zaplnění kontextového okna** — desetidílný barevný bar; primárně čte přesné `context_window.used_percentage` (počítá i s cache), s ručním fallbackem,
- **cenu session v USD** (kolik by session stála přes API),
- **délku session**, **aktuální složku** a **git větev** s indikací necommitnutých změn (`±`),
- jeden průchod `jq` místo pěti — rychlé i na pomalejších strojích.

Vychází ze statusline z tutoriálu Leonarda Grigoria ([Build & Ship with AI](https://www.youtube.com/@leonardogrig)), podstatně přepracováno.
