// Wāḥa — share links
//
// A shared piece lives at /p/<id>. Facebook (and iMessage, WhatsApp, X…) never
// run a page's JavaScript; they read the <meta> tags in the raw HTML. This edge
// function serves the normal home page, but first writes the piece's title,
// writer, a short excerpt and the writer's thumbnail into those tags.
// The page itself then draws just that one piece.

const SUPABASE_URL = "https://qddvifhkrynjbdxuvhvx.supabase.co";
const SUPABASE_KEY = "sb_publishable_8Boi1cyqkmt93NfKXoyJJg_ljW-sYjz"; // publishable: safe to ship
const WRITERS = ["amir", "simi", "mike"];

const esc = (v: unknown) =>
  String(v ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));

type Span = { t?: string };
type Block = { spans?: Span[] };
const textOf = (body: unknown) =>
  (Array.isArray(body) ? (body as Block[]) : [])
    .map((b) => (Array.isArray(b.spans) ? b.spans.map((s) => s.t ?? "").join("") : ""))
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();

function excerpt(text: string, max = 180) {
  if (text.length <= max) return text;
  const cut = text.slice(0, max);
  return cut.slice(0, Math.max(cut.lastIndexOf(" "), max - 20)).replace(/[,;:—–-]$/, "") + "…";
}

export default async (req: Request) => {
  const url = new URL(req.url);
  const id = (url.pathname.split("/")[2] || "").toLowerCase();

  const page = await fetch(new URL("/index.html", url.origin));
  let html = await page.text();

  if (/^[0-9a-f-]{36}$/.test(id)) {
    try {
      const r = await fetch(
        `${SUPABASE_URL}/rest/v1/feed?id=eq.${id}&select=id,kind,title,body,writer,writer_name`,
        { headers: { apikey: SUPABASE_KEY, accept: "application/json" } },
      );
      const rows = r.ok ? await r.json() : [];
      const p = Array.isArray(rows) ? rows[0] : null;
      if (p) {
        const writer = WRITERS.includes(p.writer) ? p.writer : "amir";
        const name = p.writer_name || "Wāḥa";
        const title = p.kind === "short" ? `A note from ${name}` : (p.title || "Untitled");
        const ogTitle = p.kind === "short" ? `A note from ${name}` : `${title} — by ${name}`;
        const desc = `From the hand of ${name} · Wāḥa — ${excerpt(textOf(p.body))}`;
        const pageUrl = `${url.origin}/p/${p.id}`;
        const image = `${url.origin}/og/${writer}.png`;
        const meta = `<!--og-->
<meta name="description" content="${esc(desc)}">
<meta property="og:site_name" content="Wāḥa">
<meta property="og:type" content="article">
<meta property="og:title" content="${esc(ogTitle)}">
<meta property="og:description" content="${esc(desc)}">
<meta property="og:url" content="${esc(pageUrl)}">
<meta property="og:image" content="${esc(image)}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="${esc(`${name}'s seal at the oasis`)}">
<meta property="article:author" content="${esc(name)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(ogTitle)}">
<meta name="twitter:description" content="${esc(desc)}">
<meta name="twitter:image" content="${esc(image)}">
<link rel="canonical" href="${esc(pageUrl)}">
<!--/og-->`;
        html = html
          .replace(/<!--og-->[\s\S]*?<!--\/og-->/, meta)
          .replace(/<title>[\s\S]*?<\/title>/, `<title>${esc(title)} — ${esc(name)} · Wāḥa</title>`);
      }
    } catch (_) {
      // if Supabase can't be reached, fall back to the site's default preview
    }
  }

  return new Response(html, {
    status: 200,
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=0, must-revalidate" },
  });
};

export const config = { path: "/p/*" };
