# Recomp Showcase (`recomp.club` Theme Component)

Discourse theme component for **recomp.club** — a community catalog for native game recompilations, decompilations, and AI-assisted binary rewrites.

## Features
- **Custom Homepage (`discovery-above`):**
  - Auto-rotating Hero Spotlight carousel for featured entries with blurred cover backdrops and quick CTAs
  - Console Hardware Rail (`N64`, `PS1`, `PS2`, `GameCube`, `Xbox 360`, `SNES`, `GBA`, `Dreamcast`, `Saturn`, `DOS / PC`) and method chips
  - Live Bento shelves for **Top Bounties & Port Requests** and **AI Rewrites & Tooling**
- **Image-Heavy Topic Card Grid:** 16:9 cover cards with system/method badges, vote counts, and per-console hover glows
- **Original System Tag Icons:** Inline SVG masks for consoles, handhelds, PC/DOS, and `ai-rewrite` tags
- **Modern Dark Obsidian UI:** `Space Grotesk`, `Plus Jakarta Sans`, and `JetBrains Mono` typography, glassmorphic header/navigation bar, dossier-style topic pages, and an animated D-pad `.spinner`
- **Assets (`assets/`):**
  - `recomp-club-logo.svg` & `recomp-club-icon.svg` — site & compact header logos
  - `recomp-splash.svg` — CSS `@keyframes` animated SVG for Discourse's `splash_screen_image`
  - `recomp-loader.svg` — standalone animated loader

## Installation
In Discourse Admin → **Customize → Themes → Install → From a git repository**:
```
https://github.com/falcosfailsafe/recomp-theme
```
Attach the component to your active theme (e.g. `Foundation` with the `Horizon Dark` color scheme).
