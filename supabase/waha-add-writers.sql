-- ============================================================================
--  Wāḥa — add Amir and Simi
--  Run once in the Supabase SQL Editor, after waha-schema.sql.
--  Safe to re-run: anyone who already exists is skipped.
--
--    Amir   amir@waha.local   key: 482917
--    Simi   simi@waha.local   key: 735260
-- ============================================================================

do $$
declare
  w record;
  uid uuid;
begin
  for w in
    select * from (values
      ('amir@waha.local', '482917'),
      ('simi@waha.local', '735260')
    ) as t(email, pass)
  loop
    if exists (select 1 from auth.users where email = w.email) then
      raise notice '% already exists — skipped', w.email;
      continue;
    end if;

    uid := gen_random_uuid();

    -- the login itself (password stored hashed, email marked confirmed)
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', w.email,
      extensions.crypt(w.pass, extensions.gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', '{}', now(), now(),
      '', '', '', ''
    );

    -- the email sign-in method attached to that login
    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), uid, uid::text,
      jsonb_build_object('sub', uid::text, 'email', w.email, 'email_verified', true),
      'email', now(), now(), now()
    );

    raise notice 'created %', w.email;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
--  Link each login to their seal (the same step as the end of waha-schema.sql)
-- ---------------------------------------------------------------------------
insert into public.writers (id, slug, name, name_ar, seal, ink)
select id, 'amir', 'Amir', 'أمير', 'palm', 'gold'
from auth.users where email = 'amir@waha.local'
on conflict (id) do nothing;

insert into public.writers (id, slug, name, name_ar, seal, ink)
select id, 'simi', 'Simi', 'سيمي', 'lotus', 'lapis'
from auth.users where email = 'simi@waha.local'
on conflict (id) do nothing;

-- Check: should list both writers with their seals
select w.name, w.seal, u.email
from public.writers w join auth.users u on u.id = w.id
order by w.name;
