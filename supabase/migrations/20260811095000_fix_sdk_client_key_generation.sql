create or replace function public.create_sdk_client(
  p_name text,
  p_slug text,
  p_plan text default 'developer'::text,
  p_monthly_event_limit bigint default 10000,
  p_allowed_origins text[] default '{}'::text[]
)
returns table(client_id uuid, api_key text)
language plpgsql
security definer
set search_path=''
as $$
declare
  v_id uuid;
  v_key text;
begin
  if not (select private.is_admin()) then raise exception 'forbidden'; end if;
  if p_plan not in ('developer','starter','pro','business','enterprise') then raise exception 'invalid_plan'; end if;

  v_key := 'ks_live_' || replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');

  insert into public.sdk_clients(name,slug,api_key_hash,plan,monthly_event_limit,allowed_origins,created_by)
  values(
    p_name,
    p_slug,
    pg_catalog.encode(extensions.digest(v_key,'sha256'),'hex'),
    p_plan,
    p_monthly_event_limit,
    p_allowed_origins,
    (select auth.uid())
  )
  returning id into v_id;

  return query select v_id, v_key;
end;
$$;
