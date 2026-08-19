-- Real rewarded-video bridge for the Konsens daily +100 Koins drop.
-- The iOS client calls claim_daily_reward_video only from Google Mobile Ads' earned-reward callback.
-- Daily amount, idempotency and wallet mutation remain server-side.

alter table public.game_daily_rewards
  add column if not exists reward_provider text,
  add column if not exists reward_ad_unit text,
  add column if not exists reward_nonce uuid;

create unique index if not exists game_daily_rewards_reward_nonce_uidx
  on public.game_daily_rewards(reward_nonce)
  where reward_nonce is not null;

create or replace function public.claim_daily_reward_video(
  p_provider text,
  p_ad_unit text,
  p_reward_nonce uuid
)
returns table(claimed boolean,amount integer,balance numeric,streak integer)
language plpgsql volatile security definer set search_path='' as $$
declare
  v_user uuid := (select auth.uid());
  v_day date := ((now() at time zone 'Europe/Paris')::date);
  v_wallet public.wallets%rowtype;
  v_streak integer := 1;
  v_previous date;
begin
  if v_user is null then raise exception 'unauthenticated'; end if;
  if lower(coalesce(p_provider,'')) <> 'admob' then raise exception 'invalid_reward_provider'; end if;
  if char_length(coalesce(p_ad_unit,'')) not between 8 and 160 then raise exception 'invalid_ad_unit'; end if;
  if p_reward_nonce is null then raise exception 'reward_nonce_required'; end if;

  -- A nonce may never be replayed, including by another authenticated session.
  if exists(
    select 1 from public.game_daily_rewards
    where reward_nonce=p_reward_nonce
  ) then
    raise exception 'reward_nonce_replayed';
  end if;

  -- The daily primary key is the authoritative anti-double-credit lock.
  if exists(
    select 1 from public.game_daily_rewards
    where user_id=v_user and reward_date=v_day
  ) then
    select * into v_wallet from public.wallets where user_id=v_user;
    select streak_days into v_streak from public.profiles where id=v_user;
    return query select false,100::integer,v_wallet.cash,v_streak;
    return;
  end if;

  select * into v_wallet
  from public.wallets
  where user_id=v_user
  for update;

  if v_wallet.user_id is null then raise exception 'wallet_missing'; end if;

  -- Re-check after taking the wallet lock to make concurrent claims deterministic.
  if exists(
    select 1 from public.game_daily_rewards
    where user_id=v_user and reward_date=v_day
  ) then
    select streak_days into v_streak from public.profiles where id=v_user;
    return query select false,100::integer,v_wallet.cash,v_streak;
    return;
  end if;

  select max(reward_date) into v_previous
  from public.game_daily_rewards
  where user_id=v_user and reward_date<v_day;

  if v_previous=v_day-1 then
    select greatest(streak_days,0)+1 into v_streak
    from public.profiles where id=v_user;
  else
    v_streak:=1;
  end if;

  update public.wallets
  set cash=cash+100,
      total_allocated=total_allocated+100,
      version=version+1,
      updated_at=now()
  where user_id=v_user;

  insert into public.game_daily_rewards(
    user_id,reward_date,amount,reward_provider,reward_ad_unit,reward_nonce
  ) values(
    v_user,v_day,100,'admob',p_ad_unit,p_reward_nonce
  );

  insert into public.allocations(user_id,amount,reason)
  values(v_user,100,'daily_rewarded_video');

  insert into public.ledger_entries(user_id,entry_type,amount,balance_after,metadata)
  values(
    v_user,
    'allocation',
    100,
    v_wallet.cash+100,
    jsonb_build_object(
      'reason','daily_rewarded_video',
      'provider','admob',
      'ad_unit',p_ad_unit,
      'reward_nonce',p_reward_nonce
    )
  );

  update public.profiles
  set streak_days=v_streak,last_active_on=v_day,updated_at=now()
  where id=v_user;

  return query select true,100::integer,(v_wallet.cash+100)::numeric,v_streak;
end $$;

revoke all on function public.claim_daily_reward_video(text,text,uuid) from public;
grant execute on function public.claim_daily_reward_video(text,text,uuid) to authenticated;

comment on function public.claim_daily_reward_video(text,text,uuid) is
  'Credits exactly 100 Koins once per Europe/Paris day after the iOS rewarded-ad earned callback. Provider/ad-unit/nonce are audited. AdMob SSV should be used as the production hardening layer.';
