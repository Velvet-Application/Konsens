-- Controlled beta bootstrap: the first registered account becomes the initial administrator.
create or replace function private.create_profile_for_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_username text; v_role text;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('konsens_first_admin'));
  v_username := 'joueur_' || substr(replace(new.id::text,'-',''),1,8);
  v_role := case when exists(select 1 from public.profiles where role='admin') then 'user' else 'admin' end;
  insert into public.profiles(id,username,display_name,avatar_seed,email,role)
  values(new.id,v_username,v_username,upper(substr(v_username,1,1)),new.email,v_role);
  insert into public.wallets(user_id,cash,total_allocated) values(new.id,0,0);
  return new;
end $$;
revoke all on function private.create_profile_for_user() from public, anon, authenticated;
