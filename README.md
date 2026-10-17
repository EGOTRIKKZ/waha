# Wāḥa

A minimal, beautiful writing platform for two voices.

## Overview

Wāḥa (واحة, "oasis") is a dual-author blog platform where each piece flows into the next like water through an oasis—newest at dawn, oldest under the stars.

**Live Demo:** Coming soon

## Features

- **Two voices, one oasis** — Amir (palm/gold) and Simi (lotus/lapis)
- **Time-of-day progression** — Posts flow from predawn → dawn → night based on publish order
- **Living sky** — Gradient transitions, orbiting sun/moon, twinkling stars
- **Illuminated pieces** — Posts worked across 5+ days with 1000+ words get special treatment
- **Short notes** — 280-character thoughts displayed as pottery shards
- **Pure HTML/CSS/JS** — No build step, deploys as-is

## Tech Stack

- **Frontend:** Pure HTML/CSS/JavaScript (no frameworks)
- **Database:** Supabase (PostgreSQL + Row Level Security)
- **Hosting:** Netlify (static site)
- **Auth:** Supabase Auth (private writer login)

## Files

- `waha-index.html` — Public reading interface
- `waha-editor.html` — Private writing interface  
- `waha-schema.sql` — Database setup (run in Supabase SQL editor)

## Setup

### 1. Create Supabase Project

1. Create new project at [supabase.com](https://supabase.com)
2. Go to SQL Editor
3. Paste contents of `waha-schema.sql` and run
4. Go to Authentication → Settings → Disable "Enable email confirmations"
5. Go to Authentication → Users → Add two users:
   - `amir@waha.local` (set password)
   - `simi@waha.local` (set password)

### 2. Configure Environment

The editor needs your Supabase credentials. Add these to the top of `waha-editor.html`:

```javascript
const SUPABASE_URL = 'https://YOUR-PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'your-anon-key-here';
```

Get these from: Supabase Project Settings → API

### 3. Deploy to Netlify

1. Push this repo to GitHub
2. Connect to Netlify
3. Deploy settings:
   - Build command: (leave empty)
   - Publish directory: `.`
4. Deploy!

## Usage

### For Readers

Visit the site. Posts flow from newest (dawn) to oldest (deep night). The sky transitions as you scroll.

### For Writers

1. Press and hold the Arabic wordmark "واحة" for ~1 second
2. Choose your seal (Amir/palm or Simi/lotus)
3. Enter your password
4. Write!

**Long pieces:** Full articles with formatting (drop caps, pull quotes, ornamental breaks)  
**Short notes:** Quick thoughts (280 characters max, displayed as pottery shards)

## Design Philosophy

Egyptian/Arabic aesthetic inspired by manuscripts, pottery, and desert landscapes. Every element—the seals, cartouches, water reflections, sand textures—serves the oasis metaphor.

---

© 2026 Amir & Simi
