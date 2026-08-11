create or replace function public.start_premium_beta_trial()
returns table(status text, trial_ends_at timestamptz, subscription_tier text)
language plpgsql
security definer
set search_path=''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_end timestamptz;
begin
  if v_uid is null then raise exception 'authentication_required'; end if;

  if exists(
    select 1
    from public.premium_access pa
    where pa.user_id = v_uid
      and pa.status in ('trial','active')
  ) then
    select pa.trial_ends_at into v_end
    from public.premium_access pa
    where pa.user_id = v_uid;

    update public.profiles
      set subscription_tier='premium', monetization_updated_at=now()
      where id=v_uid;

    return query select 'already_active'::text, v_end, 'premium'::text;
    return;
  end if;

  v_end := now() + interval '14 days';
  insert into public.premium_access(user_id,status,trial_ends_at,started_at,updated_at)
  values(v_uid,'trial',v_end,now(),now())
  on conflict(user_id) do update
    set status='trial', trial_ends_at=v_end, started_at=now(), updated_at=now();

  update public.profiles
    set subscription_tier='premium', monetization_updated_at=now()
    where id=v_uid;

  return query select 'trial'::text, v_end, 'premium'::text;
end;
$$;
