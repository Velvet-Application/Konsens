-- Strict AdMob rewarded-video bridge for the Konsens daily +100 Koins drop.
-- SECURITY MODEL
-- 1. The authenticated app can only create/read a short-lived reward intent.
-- 2. The iOS earned callback never mutates the wallet.
-- 3. Only service_role can finalize an intent after the Edge Function verifies Google's SSV signature.
-- 4. reward_nonce, AdMob transaction_id and (user_id,reward_date) are all idempotency locks.

alter table public.game_daily_rewards
  add column if not exists reward_provider text,
  add column if not exists reward_ad_unit text,
  add column if not exists reward_nonce uuid,
  add column if not exists ssv_transaction_id text,
  add column if not exists ssv_verified_at timestamptz;

create unique index if not exists game_daily_rewards_reward_nonce_uidx
  on public.game_daily_rewards(reward_nonce)
  where reward_nonce is not null;

create unique index if not exists game_daily_rewards_ssv_transaction_uidx
  on public.game_daily_rewards(ssv_transaction_id)
  where ssv_transaction_id is not null;

create table if not exists public.admob_reward_intents (
  reward_nonce uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  reward_date date not null,
  ad_unit text not null,
  status text not null default 'pending'
    check (status in ('pending','verified','expired','rejected')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '6 hours'),
  verified_at timestamptz,
  ssv_transaction_id text unique,
  ssv_timestamp bigint,
  ad_network text,
  reward_item text,
  reward_amount numeric,
  rejection_reason text
);

create index if not exists admob_reward_intents_user_day_idx
  on public.admob_reward_intents(user_id,reward_date,created_at desc);

create unique index if not exists admob_reward_intents_one_pending_per_day_uidx
  on public.admob_reward_intents(user_id,reward_date)
  where status='pending';

alter table public.admob_reward_intents enable row level security;
drop policy if exists admob_reward_intents_read_own on public.admob_reward_intents;
create policy admob_reward_intents_read_own on public.admob_reward_intents
  for select to authenticated
  using ((select auth.uid())=user_id);

revoke all on public.admob_reward_intents from public,anon,authenticated;
grant select on public.admob_reward_intents to authenticated;

-- The old client-authoritative RPC must never remain callable after this migration.
drop function if exists public.claim_daily_reward_video(text,text,uuid);

create or replace function public.begin_daily_reward_video(p_ad_unit text)
returns table(reward_nonce uuid,expires_at timestamptz)
language plpgsql volatile security definer set search_path='' as $$
declare
  v_user uuid := (select auth.uid());
  v_day date := ((now() at time zone 'Europe/Paris')::date);
  v_nonce uuid;
  v_expires timestamptz;
begin
  if v_user is null then raise exception 'unauthenticated'; end if;
  if char_length(coalesce(p_ad_unit,'')) not between 8 and 160 then
    raise exception 'invalid_ad_unit';
  end if;

  if exists(
    select 1 from public.game_daily_rewards r
    where r.user_id=v_user and r.reward_date=v_day
  ) then
    raise exception 'daily_reward_already_claimed';
  end if;

  update public.admob_reward_intents
  set status='expired'
  where user_id=v_user
    and reward_date=v_day
    and status='pending'
    and expires_at<=now();

  select i.reward_nonce,i.expires_at
    into v_nonce,v_expires
  from public.admob_reward_intents i
  where i.user_id=v_user
    and i.reward_date=v_day
    and i.status='pending'
    and i.expires_at>now()
  order by i.created_at desc
  limit 1;

  if v_nonce is null then
    insert into public.admob_reward_intents(
      user_id,reward_date,ad_unit,status,expires_at
    ) values(
      v_user,v_day,p_ad_unit,'pending',now()+interval '6 hours'
    )
    on conflict (user_id,reward_date) where status='pending'
    do update set ad_unit=excluded.ad_unit
    returning admob_reward_intents.reward_nonce,admob_reward_intents.expires_at
      into v_nonce,v_expires;
  end if;

  return query select v_nonce,v_expires;
end $$;

revoke all on function public.begin_daily_reward_video(text) from public;
grant execute on function public.begin_daily_reward_video(text) to authenticated;

create or replace function public.get_my_reward_video_intent(p_reward_nonce uuid)
returns table(status text,verified_at timestamptz,claimed boolean)
language sql stable security definer set search_path='' as $$
  select
    case
      when i.status='pending' and i.expires_at<=now() then 'expired'::text
      else i.status
    end,
    i.verified_at,
    exists(
      select 1 from public.game_daily_rewards r
      where r.reward_nonce=i.reward_nonce
    ) as claimed
  from public.admob_reward_intents i
  where i.reward_nonce=p_reward_nonce
    and i.user_id=(select auth.uid())
  limit 1;
$$;

revoke all on function public.get_my_reward_video_intent(uuid) from public;
grant execute on function public.get_my_reward_video_intent(uuid) to authenticated;

create or replace function public.finalize_daily_reward_video_ssv(
  p_user_id uuid,
  p_reward_nonce uuid,
  p_ad_unit text,
  p_transaction_id text,
  p_timestamp bigint,
  p_ad_network text,
  p_reward_item text,
  p_reward_amount numeric
)
returns table(claimed boolean,amount integer,balance numeric,streak integer)
language plpgsql volatile security definer set search_path='' as $$
declare
  v_intent public.admob_reward_intents%rowtype;
  v_wallet public.wallets%rowtype;
  v_streak integer := 1;
  v_previous date;
  v_existing_tx uuid;
begin
  if p_user_id is null or p_reward_nonce is null then
    raise exception 'invalid_reward_identity';
  end if;
  if char_length(coalesce(p_transaction_id,'')) not between 8 and 220 then
    raise exception 'invalid_transaction_id';
  end if;

  select i.* into v_intent
  from public.admob_reward_intents i
  where i.reward_nonce=p_reward_nonce
  for update;

  if v_intent.reward_nonce is null then
    raise exception 'reward_intent_not_found';
  end if;
  if v_intent.user_id<>p_user_id then
    raise exception 'reward_user_mismatch';
  end if;
  if v_intent.ad_unit<>p_ad_unit then
    raise exception 'reward_ad_unit_mismatch';
  end if;

  if v_intent.status='verified' then
    if v_intent.ssv_transaction_id<>p_transaction_id then
      raise exception 'reward_already_verified_with_other_transaction';
    end if;
    select * into v_wallet from public.wallets where user_id=p_user_id;
    select streak_days into v_streak from public.profiles where id=p_user_id;
    return query select false,100::integer,coalesce(v_wallet.cash,0)::numeric,coalesce(v_streak,1);
    return;
  end if;

  if v_intent.status<>'pending' then
    raise exception 'reward_intent_not_pending';
  end if;
  if v_intent.expires_at<=now() then
    update public.admob_reward_intents
      set status='expired',rejection_reason='intent_expired'
    where reward_nonce=p_reward_nonce;
    raise exception 'reward_intent_expired';
  end if;

  select i.reward_nonce into v_existing_tx
  from public.admob_reward_intents i
  where i.ssv_transaction_id=p_transaction_id
  limit 1;
  if v_existing_tx is not null and v_existing_tx<>p_reward_nonce then
    raise exception 'ssv_transaction_replayed';
  end if;

  select * into v_wallet
  from public.wallets
  where user_id=p_user_id
  for update;
  if v_wallet.user_id is null then raise exception 'wallet_missing'; end if;

  -- Mark the cryptographically verified event before mutating the wallet.
  update public.admob_reward_intents
  set status='verified',
      verified_at=now(),
      ssv_transaction_id=p_transaction_id,
      ssv_timestamp=p_timestamp,
      ad_network=p_ad_network,
      reward_item=p_reward_item,
      reward_amount=p_reward_amount,
      rejection_reason=null
  where reward_nonce=p_reward_nonce;

  -- Daily reward uniqueness is the final anti-double-credit lock.
  if exists(
    select 1 from public.game_daily_rewards r
    where r.user_id=p_user_id and r.reward_date=v_intent.reward_date
  ) then
    select streak_days into v_streak from public.profiles where id=p_user_id;
    return query select false,100::integer,v_wallet.cash::numeric,coalesce(v_streak,1);
    return;
  end if;

  select max(reward_date) into v_previous
  from public.game_daily_rewards
  where user_id=p_user_id and reward_date<v_intent.reward_date;

  if v_previous=v_intent.reward_date-1 then
    select greatest(streak_days,0)+1 into v_streak
    from public.profiles where id=p_user_id;
  else
    v_streak:=1;
  end if;

  update public.wallets
  set cash=cash+100,
      total_allocated=total_allocated+100,
      version=version+1,
      updated_at=now()
  where user_id=p_user_id;

  insert into public.game_daily_rewards(
    user_id,reward_date,amount,reward_provider,reward_ad_unit,reward_nonce,
    ssv_transaction_id,ssv_verified_at
  ) values(
    p_user_id,v_intent.reward_date,100,'admob',p_ad_unit,p_reward_nonce,
    p_transaction_id,now()
  );

  insert into public.allocations(user_id,amount,reason)
  values(p_user_id,100,'daily_rewarded_video_ssv');

  insert into public.ledger_entries(user_id,entry_type,amount,balance_after,metadata)
  values(
    p_user_id,
    'allocation',
    100,
    v_wallet.cash+100,
    jsonb_build_object(
      'reason','daily_rewarded_video_ssv',
      'provider','admob',
      'ad_unit',p_ad_unit,
      'reward_nonce',p_reward_nonce,
      'ssv_transaction_id',p_transaction_id,
      'ssv_timestamp',p_timestamp,
      'ad_network',p_ad_network,
      'reward_item',p_reward_item,
      'reward_amount',p_reward_amount
    )
  );

  update public.profiles
  set streak_days=v_streak,
      last_active_on=greatest(coalesce(last_active_on,v_intent.reward_date),v_intent.reward_date),
      updated_at=now()
  where id=p_user_id;

  return query select true,100::integer,(v_wallet.cash+100)::numeric,v_streak;
end $$;

revoke all on function public.finalize_daily_reward_video_ssv(uuid,uuid,text,text,bigint,text,text,numeric)
  from public,anon,authenticated;
grant execute on function public.finalize_daily_reward_video_ssv(uuid,uuid,text,text,bigint,text,text,numeric)
  to service_role;

comment on function public.begin_daily_reward_video(text) is
  'Creates or reuses a short-lived server-side nonce for the authenticated user daily rewarded ad. Never credits Koins.';

comment on function public.finalize_daily_reward_video_ssv(uuid,uuid,text,text,bigint,text,text,numeric) is
  'Service-role-only wallet mutation. Called only after Google AdMob SSV ECDSA verification by the admob-reward-ssv Edge Function.';
