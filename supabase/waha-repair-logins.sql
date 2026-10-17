-- ============================================================================
--  Wāḥa — repair Amir's and Simi's logins
--  Paste into the Supabase SQL Editor and Run. Safe to run more than once.
--
--  It creates either login if it's missing, resets both keys, marks the email
--  as confirmed, fills in blank fields Supabase's sign-in expects, makes sure
--  each login has its email sign-in method, re-links the seals, and then shows
--  a report table.
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
    select id into uid from auth.users where lower(email) = w.email limit 1;

    if uid is null then
      uid := gen_random_uuid();
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
      raise notice 'created %', w.email;
    end if;

    -- reset the key, confirm the email, and fill blanks the sign-in can't read as empty
    update auth.users set
      encrypted_password         = extensions.crypt(w.pass, extensions.gen_salt('bf')),
      email_confirmed_at         = coalesce(email_confirmed_at, now()),
      aud                        = coalesce(nullif(aud, ''), 'authenticated'),
      role                       = coalesce(nullif(role, ''), 'authenticated'),
      raw_app_meta_data          = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"provider":"email","providers":["email"]}',
      raw_user_meta_data         = coalesce(raw_user_meta_data, '{}'::jsonb),
      confirmation_token         = coalesce(confirmation_token, ''),
      recovery_token             = coalesce(recovery_token, ''),
      email_change_token_new     = coalesce(email_change_token_new, ''),
      email_change               = coalesce(email_change, ''),
      email_change_token_current = coalesce(email_change_token_current, ''),
      phone_change               = coalesce(phone_change, ''),
      phone_change_token         = coalesce(phone_change_token, ''),
      reauthentication_token     = coalesce(reauthentication_token, ''),
      banned_until               = null,
      updated_at                 = now()
    where id = uid;

    -- the email sign-in method for that login
    if not exists (select 1 from auth.identities where user_id = uid and provider = 'email') then
      insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
      values (gen_random_uuid(), uid, uid::text,
              jsonb_build_object('sub', uid::text, 'email', w.email, 'email_verified', true),
              'email', now(), now(), now());
      raise notice 'added sign-in method for %', w.email;
    end if;
  end loop;
end $$;

-- re-link each login to their seal
insert into public.writers (id, slug, name, name_ar, seal, ink)
select id, 'amir', 'Amir', 'أمير', 'palm', 'gold' from auth.users where lower(email) = 'amir@waha.local'
on conflict (id) do nothing;
insert into public.writers (id, slug, name, name_ar, seal, ink)
select id, 'simi', 'Simi', 'سيمي', 'lotus', 'lapis' from auth.users where lower(email) = 'simi@waha.local'
on conflict (id) do nothing;

-- Report: every column should read true / 1
select
  u.email,
  u.email_confirmed_at is not null                                   as confirmed,
  u.encrypted_password = extensions.crypt(
    case lower(u.email) when 'amir@waha.local' then '482917' else '735260' end,
    u.encrypted_password)                                            as key_works,
  (select count(*) from auth.identities i where i.user_id = u.id)    as sign_in_methods,
  exists (select 1 from public.writers wr where wr.id = u.id)        as linked_to_seal
from auth.users u
where lower(u.email) in ('amir@waha.local', 'simi@waha.local')
order by u.email;
