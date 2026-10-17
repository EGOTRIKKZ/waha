-- ============================================================================
--  Wāḥa — Supabase schema
--  Paste into the Supabase SQL editor and run once on a fresh project.
--
--  BEFORE running the seed at the bottom:
--    1. Authentication → Providers → Email: turn OFF "Allow new users to sign up"
--       and OFF "Confirm email".
--    2. Authentication → Users → Add user (twice):
--         amir@waha.local   password = Amir's key
--         simi@waha.local   password = Simi's key
--       These are private login names, not real inboxes. The secret entrance
--       turns "pick a seal + type your key" into signInWithPassword() with them,
--       so no real email address ever appears in the site's code.
-- ============================================================================


-- ---------------------------------------------------------------------------
--  Writers: one row per person, tied to their Supabase login
-- ---------------------------------------------------------------------------
create table public.writers (
  id          uuid primary key references auth.users (id) on delete cascade,
  slug        text not null unique check (slug ~ '^[a-z]+$'),   -- 'amir', 'simi'
  name        text not null,                                     -- 'Amir'
  name_ar     text not null,                                     -- 'أمير'
  seal        text not null check (seal in ('palm', 'lotus')),
  ink         text not null check (ink  in ('gold', 'lapis')),
  created_at  timestamptz not null default now()
);


-- ---------------------------------------------------------------------------
--  Posts
--
--  body is a list of lines ("blocks"), exactly what the editor's toggles make:
--    [
--      { "type": "p",     "opening": true, "spans": [ { "t": "The ferry across…" } ] },
--      { "type": "quote",                  "spans": [ { "t": "Water doesn't care who rows." } ] },
--      { "type": "p",     "break": true,   "spans": [ { "t": "She said it " }, { "t": "without", "i": true }, { "t": " looking up." } ] }
--    ]
--    type     'p' (paragraph) or 'quote' (the bordered pull-quote)
--    opening  big first letter on this line (one per post)
--    break    the ◆◆◆ ornament sits above this line
--    spans    runs of text; "i": true = italic
--
--  Storing lines like this instead of page code means the design can change
--  later without touching a single old post, and nothing unsafe gets stored.
--  The scene's time of day is NOT stored: the home page works it out from order.
--  The little sun/moon marker comes from published_at (the hour it was written).
--
--  tended_days  every distinct day the writer worked on the piece (their local date,
--               sent by the editor on each autosave)
--  revision     changes to an already-published piece, held privately until the
--               writer taps "Save changes" — readers keep seeing the live version
--  illuminated  set by the database itself, once, at the moment of publishing
-- ---------------------------------------------------------------------------
create type public.post_kind   as enum ('long', 'short');
create type public.post_status as enum ('draft', 'published');

-- plain text of a body, used for the 280-character rule and for search later
create or replace function public.blocks_text(body jsonb)
returns text
language sql
immutable
as $$
  select coalesce(string_agg(s ->> 't', '' order by b.ord, s.ord), '')
  from jsonb_array_elements(coalesce(body, '[]'::jsonb)) with ordinality as b(blk, ord),
       jsonb_array_elements(coalesce(b.blk -> 'spans', '[]'::jsonb)) with ordinality as s(s, ord)
$$;

create table public.posts (
  id            uuid primary key default gen_random_uuid(),
  writer_id     uuid not null references public.writers (id) on delete cascade,
  kind          public.post_kind   not null default 'long',
  status        public.post_status not null default 'draft',
  title         text,
  body          jsonb not null default '[]'::jsonb,
  body_text     text generated always as (public.blocks_text(body)) stored,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  published_at  timestamptz,
  tended_days   date[] not null default '{}',
  revision      jsonb,                          -- {"title": "...", "body": [ ...blocks... ]} or null
  illuminated   boolean not null default false,

  -- drafts can be anything; published posts must be complete
  constraint published_long_has_title
    check (kind = 'short' or status = 'draft' or length(trim(coalesce(title, ''))) > 0),
  constraint published_has_words
    check (status = 'draft' or length(trim(body_text)) > 0),
  constraint short_note_limit                      -- drafts may run over while being trimmed
    check (kind = 'long' or status = 'draft' or char_length(body_text) <= 280),
  constraint body_is_list
    check (jsonb_typeof(body) = 'array'),
  constraint revision_only_when_live
    check (revision is null or status = 'published')
);

-- the home page asks for "published, newest first" — make that fast
create index posts_feed_idx  on public.posts (published_at desc) where status = 'published';
create index posts_owner_idx on public.posts (writer_id, updated_at desc);


-- ---------------------------------------------------------------------------
--  Illuminated: what it takes for a long piece to bloom.
--  Change the two numbers here to tune it (keep the editor's ILLUM_DAYS /
--  ILLUM_WORDS in step so its "growing" hints match).
-- ---------------------------------------------------------------------------
create or replace function public.earns_illumination(kind public.post_kind, tended_days date[], body jsonb)
returns boolean
language sql
immutable
as $$
  select kind = 'long'
     and cardinality(tended_days) >= 5                                                            -- days tended
     and coalesce(array_length(regexp_split_to_array(nullif(trim(public.blocks_text(body)), ''), '\s+'), 1), 0) >= 1000   -- words
$$;

-- keep updated_at fresh; at the moment of release, stamp the time and decide Illuminated
create or replace function public.touch_post()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  if new.status = 'published'
     and (tg_op = 'INSERT' or old.status <> 'published') then
    if new.published_at is null then
      new.published_at := now();
    end if;
    new.illuminated := public.earns_illumination(new.kind, new.tended_days, new.body);
    new.revision := null;
  elsif tg_op = 'UPDATE' then
    new.illuminated := old.illuminated;               -- writers can't flip it by hand
  end if;
  return new;
end;
$$;

create trigger posts_touch
before insert or update on public.posts
for each row execute function public.touch_post();


-- ---------------------------------------------------------------------------
--  Security (row level security)
--    Readers (not signed in): see writers and PUBLISHED posts only.
--    Amir / Simi: also see, create, edit and delete THEIR OWN posts and drafts.
--    Neither can see or change the other's drafts.
-- ---------------------------------------------------------------------------
alter table public.writers enable row level security;
alter table public.posts   enable row level security;

create policy "anyone can see who the writers are"
  on public.writers for select
  to anon, authenticated
  using (true);

create policy "anyone can read published posts"
  on public.posts for select
  to anon, authenticated
  using (status = 'published');

create policy "writers can read their own drafts"
  on public.posts for select
  to authenticated
  using (writer_id = (select auth.uid()));

create policy "writers can create their own posts"
  on public.posts for insert
  to authenticated
  with check (writer_id = (select auth.uid()));

create policy "writers can edit their own posts"
  on public.posts for update
  to authenticated
  using (writer_id = (select auth.uid()))
  with check (writer_id = (select auth.uid()));

create policy "writers can delete their own posts"
  on public.posts for delete
  to authenticated
  using (writer_id = (select auth.uid()));


-- ---------------------------------------------------------------------------
--  The feed the home page reads: published posts with their writer's seal,
--  newest first. Row level security still applies (security_invoker).
-- ---------------------------------------------------------------------------
create view public.feed
with (security_invoker = on)
as
select
  p.id,
  p.kind,
  p.title,
  p.body,
  p.published_at,
  p.illuminated,
  p.tended_days,
  w.slug     as writer,
  w.name     as writer_name,
  w.name_ar  as writer_name_ar,
  w.seal,
  w.ink
from public.posts p
join public.writers w on w.id = p.writer_id
where p.status = 'published'
order by p.published_at desc;

grant select on public.feed to anon, authenticated;


-- ---------------------------------------------------------------------------
--  Seed the two writers (run after creating the two users — see top)
-- ---------------------------------------------------------------------------
insert into public.writers (id, slug, name, name_ar, seal, ink)
select id, 'amir', 'Amir', 'أمير', 'palm', 'gold'
from auth.users where email = 'amir@waha.local'
on conflict (id) do nothing;

insert into public.writers (id, slug, name, name_ar, seal, ink)
select id, 'simi', 'Simi', 'سيمي', 'lotus', 'lapis'
from auth.users where email = 'simi@waha.local'
on conflict (id) do nothing;
