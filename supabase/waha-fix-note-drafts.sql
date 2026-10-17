-- Wāḥa — small fix: let a short-note DRAFT run past 280 characters while it's being trimmed.
-- Published notes still have to be 280 or fewer. Run once in the Supabase SQL Editor.
alter table public.posts drop constraint if exists short_note_limit;
alter table public.posts add constraint short_note_limit
  check (kind = 'long' or status = 'draft' or char_length(body_text) <= 280);
