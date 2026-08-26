-- KONSENS V2 game loop: Google AdMob rewarded daily drops + league-created challenges.
-- Client rewarded callback is sufficient for beta testing. Before public launch, switch
-- daily reward confirmation to Google AdMob server-side verification (SSV).

create or replace function public.get_my_daily_reward_status()
returns table(claimable boolean,amount integer,claimed_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare
  v_user uuid := (select auth.uid());
  v_day date := ((now() at time zone 'Europe/Paris')::date);
  v_streak integer := 1;
  v_last date;
  v_amount integer := 100;
  v_claimed public.game_daily_rewards%rowtype;
begin
  if v_user is null then raise exception 'unauthenticated'; end if;

  select * into v_claimed
  from public.game_daily_rewards
  where user_id=v_user and reward_date=v_day
  limit 1;

  if v_claimed.user_id is not null then
    return query select false,v_claimed.amount,v_claimed.claimed_at;
    return;
  end if;

  select max(reward_date) into v_last
  from public.game_daily_rewards where user_id=v_user and reward_date<v_day;

  if v_last=v_day-1 then
    select greatest(streak_days,0)+1 into v_streak from public.profiles where id=v_user;
  else
    v_streak:=1;
  end if;

  v_amount:=case least(v_streak,7)
    when 1 then 100
    when 2 then 120
    when 3 then 150
    when 4 then 200
    when 5 then 250
    when 6 then 350
    else 500
  end;

  return query select true,v_amount,null::timestamptz;
end $$;
revoke all on function public.get_my_daily_reward_status() from public;
grant execute on function public.get_my_daily_reward_status() to authenticated;

create or replace function public.claim_daily_reward_admob()
returns table(claimed boolean,amount integer,balance numeric,streak integer)
language plpgsql volatile security definer set search_path='' as $$
declare
  v_user uuid := (select auth.uid());
  v_day date := ((now() at time zone 'Europe/Paris')::date);
  v_wallet public.wallets%rowtype;
  v_previous date;
  v_streak integer := 1;
  v_amount integer := 100;
  v_existing integer;
begin
  if v_user is null then raise exception 'unauthenticated'; end if;

  select r.amount into v_existing
  from public.game_daily_rewards r
  where r.user_id=v_user and r.reward_date=v_day;

  if v_existing is not null then
    select * into v_wallet from public.wallets where user_id=v_user;
    select streak_days into v_streak from public.profiles where id=v_user;
    return query select false,v_existing,v_wallet.cash,v_streak;
    return;
  end if;

  select * into v_wallet from public.wallets where user_id=v_user for update;
  if v_wallet.user_id is null then raise exception 'wallet_missing'; end if;

  select max(reward_date) into v_previous
  from public.game_daily_rewards where user_id=v_user and reward_date<v_day;

  if v_previous=v_day-1 then
    select greatest(streak_days,0)+1 into v_streak from public.profiles where id=v_user;
  else
    v_streak:=1;
  end if;

  v_amount:=case least(v_streak,7)
    when 1 then 100
    when 2 then 120
    when 3 then 150
    when 4 then 200
    when 5 then 250
    when 6 then 350
    else 500
  end;

  update public.wallets
  set cash=cash+v_amount,total_allocated=total_allocated+v_amount,version=version+1,updated_at=now()
  where user_id=v_user;

  insert into public.game_daily_rewards(user_id,reward_date,amount,ad_event_id)
  values(v_user,v_day,v_amount,null);

  insert into public.allocations(user_id,amount,reason)
  values(v_user,v_amount,'daily_admob_rewarded_collect');

  insert into public.ledger_entries(user_id,entry_type,amount,balance_after,metadata)
  values(
    v_user,'allocation',v_amount,v_wallet.cash+v_amount,
    jsonb_build_object('reason','daily_admob_rewarded_collect','provider','google_admob')
  );

  update public.profiles
  set streak_days=v_streak,last_active_on=v_day,updated_at=now()
  where id=v_user;

  return query select true,v_amount,(v_wallet.cash+v_amount)::numeric,v_streak;
end $$;
revoke all on function public.claim_daily_reward_admob() from public;
grant execute on function public.claim_daily_reward_admob() to authenticated;

create table if not exists public.league_challenges (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  creator_id uuid not null references public.profiles(id) on delete cascade,
  opponent_id uuid references public.profiles(id) on delete set null,
  question text not null check (char_length(question) between 8 and 140),
  stake integer not null check (stake between 25 and 1000),
  status text not null default 'open' check (status in ('open','accepted','cancelled')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  check (opponent_id is null or opponent_id<>creator_id)
);

create index if not exists league_challenges_league_time_idx
  on public.league_challenges(league_id,created_at desc);

alter table public.league_challenges enable row level security;
revoke all on public.league_challenges from anon,authenticated;

create or replace function public.create_league_challenge(p_question text,p_stake integer)
returns uuid language plpgsql volatile security definer set search_path='' as $$
declare
  v_user uuid := (select auth.uid());
  v_league uuid;
  v_id uuid;
  v_cash numeric;
begin
  if v_user is null then raise exception 'unauthenticated'; end if;
  p_question:=btrim(coalesce(p_question,''));
  if char_length(p_question) not between 8 and 140 then raise exception 'invalid_question'; end if;
  if p_stake not between 25 and 1000 then raise exception 'invalid_stake'; end if;

  select cash into v_cash from public.wallets where user_id=v_user;
  if coalesce(v_cash,0)<p_stake then raise exception 'insufficient_koins'; end if;

  v_league:=private.ensure_game_league(v_user);
  insert into public.league_challenges(league_id,creator_id,question,stake)
  values(v_league,v_user,p_question,p_stake)
  returning id into v_id;

  return v_id;
end $$;
revoke all on function public.create_league_challenge(text,integer) from public;
grant execute on function public.create_league_challenge(text,integer) to authenticated;

create or replace function public.accept_league_challenge(p_challenge_id uuid)
returns boolean language plpgsql volatile security definer set search_path='' as $$
declare
  v_user uuid := (select auth.uid());
  v_league uuid;
  v_challenge public.league_challenges%rowtype;
  v_cash numeric;
begin
  if v_user is null then raise exception 'unauthenticated'; end if;
  v_league:=private.ensure_game_league(v_user);

  select * into v_challenge
  from public.league_challenges
  where id=p_challenge_id for update;

  if v_challenge.id is null then raise exception 'challenge_missing'; end if;
  if v_challenge.league_id<>v_league then raise exception 'wrong_league'; end if;
  if v_challenge.creator_id=v_user then raise exception 'self_challenge'; end if;
  if v_challenge.status<>'open' then raise exception 'challenge_closed'; end if;

  select cash into v_cash from public.wallets where user_id=v_user;
  if coalesce(v_cash,0)<v_challenge.stake then raise exception 'insufficient_koins'; end if;

  update public.league_challenges
  set opponent_id=v_user,status='accepted',accepted_at=now()
  where id=p_challenge_id;

  insert into public.notification_events(user_id,kind,title,body,payload,dedupe_key)
  values(
    v_challenge.creator_id,
    'league',
    '⚔️ Défi accepté',
    'Quelqu’un de ta ligue vient de prendre ton pari à '||v_challenge.stake||' Koins.',
    jsonb_build_object('route','league','challenge_id',p_challenge_id),
    'league-challenge-accepted:'||p_challenge_id
  ) on conflict(dedupe_key) where dedupe_key is not null do nothing;

  return true;
end $$;
revoke all on function public.accept_league_challenge(uuid) from public;
grant execute on function public.accept_league_challenge(uuid) to authenticated;

create or replace function public.get_my_league_challenges(p_limit integer default 20)
returns table(
  id uuid,
  creator_id uuid,
  creator_username text,
  opponent_username text,
  question text,
  stake integer,
  status text,
  created_at timestamptz,
  is_mine boolean
)
language plpgsql volatile security definer set search_path='' as $$
declare
  v_user uuid := (select auth.uid());
  v_league uuid;
begin
  if v_user is null then raise exception 'unauthenticated'; end if;
  v_league:=private.ensure_game_league(v_user);

  return query
  select c.id,c.creator_id,creator.username,opponent.username,c.question,c.stake,c.status,c.created_at,(c.creator_id=v_user)
  from public.league_challenges c
  join public.profiles creator on creator.id=c.creator_id
  left join public.profiles opponent on opponent.id=c.opponent_id
  where c.league_id=v_league and c.status in ('open','accepted')
  order by case when c.status='open' then 0 else 1 end,c.created_at desc
  limit greatest(1,least(coalesce(p_limit,20),50));
end $$;
revoke all on function public.get_my_league_challenges(integer) from public;
grant execute on function public.get_my_league_challenges(integer) to authenticated;
