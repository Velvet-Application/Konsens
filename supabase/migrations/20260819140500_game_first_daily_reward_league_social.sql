-- Konsens game-first loop: rewarded daily drop, social league reactions and league push events.

alter table public.ad_slots drop constraint if exists ad_slots_placement_check;
alter table public.ad_slots add constraint ad_slots_placement_check
  check (placement in ('feed_native','challenge_sponsor','post_prediction','rewarded_daily'));

alter table public.ad_events drop constraint if exists ad_events_placement_check;
alter table public.ad_events add constraint ad_events_placement_check
  check (placement in ('feed_native','challenge_sponsor','post_prediction','rewarded_daily'));

alter table public.notification_events drop constraint if exists notification_events_kind_check;
alter table public.notification_events add constraint notification_events_kind_check
  check(kind in('market_move','asset_move','whale_move','system','premium','league'));

insert into public.ad_slots(slot_key,placement,description) values
  ('daily_rewarded_collect','rewarded_daily','Spot sponsorisé obligatoire avant la collecte quotidienne de 100 Koins')
on conflict (slot_key) do update
set placement=excluded.placement,description=excluded.description,is_active=true;

create table if not exists public.game_daily_rewards (
  user_id uuid not null references public.profiles(id) on delete cascade,
  reward_date date not null,
  amount integer not null default 100 check (amount > 0),
  ad_event_id bigint references public.ad_events(id) on delete set null,
  claimed_at timestamptz not null default now(),
  primary key(user_id,reward_date)
);

alter table public.game_daily_rewards enable row level security;
drop policy if exists game_daily_rewards_read_own on public.game_daily_rewards;
create policy game_daily_rewards_read_own on public.game_daily_rewards
  for select to authenticated using ((select auth.uid())=user_id);
revoke all on public.game_daily_rewards from anon,authenticated;
grant select on public.game_daily_rewards to authenticated;

create table if not exists public.league_reactions (
  id bigint generated always as identity primary key,
  league_id uuid not null references public.leagues(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  target_id uuid not null references public.profiles(id) on delete cascade,
  reaction text not null check (reaction in ('😂','🔥','👀','👏','😈','💀')),
  created_at timestamptz not null default now(),
  check (actor_id <> target_id)
);

create index if not exists league_reactions_league_time_idx
  on public.league_reactions(league_id,created_at desc);
alter table public.league_reactions enable row level security;
revoke all on public.league_reactions from anon,authenticated;

create or replace function public.track_ad_event(
  p_campaign_id uuid,
  p_creative_id uuid,
  p_event_type text,
  p_placement text,
  p_session_id text,
  p_slot_key text default null,
  p_resource_id text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns bigint language plpgsql volatile security definer set search_path = '' as $$
declare v_id bigint;
begin
  if p_event_type not in ('impression','click','conversion') then raise exception 'invalid_event_type'; end if;
  if p_placement not in ('feed_native','challenge_sponsor','post_prediction','rewarded_daily') then raise exception 'invalid_placement'; end if;
  if char_length(coalesce(p_session_id,'')) not between 8 and 100 then raise exception 'invalid_session'; end if;
  if not exists(
    select 1 from public.ad_creatives
    where id=p_creative_id and campaign_id=p_campaign_id and is_active
  ) then raise exception 'invalid_creative'; end if;

  insert into public.ad_events(
    campaign_id,creative_id,user_id,session_id,event_type,placement,slot_key,resource_id,metadata
  ) values(
    p_campaign_id,p_creative_id,(select auth.uid()),p_session_id,p_event_type,p_placement,
    p_slot_key,p_resource_id,coalesce(p_metadata,'{}'::jsonb)
  ) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.track_ad_event(uuid,uuid,text,text,text,text,text,jsonb) from public;
grant execute on function public.track_ad_event(uuid,uuid,text,text,text,text,text,jsonb) to anon,authenticated;

create or replace function public.get_my_daily_reward_status()
returns table(claimable boolean,amount integer,claimed_at timestamptz)
language sql stable security definer set search_path='' as $$
  select
    not exists(
      select 1 from public.game_daily_rewards r
      where r.user_id=(select auth.uid())
        and r.reward_date=((now() at time zone 'Europe/Paris')::date)
    ) as claimable,
    100::integer as amount,
    (
      select r.claimed_at from public.game_daily_rewards r
      where r.user_id=(select auth.uid())
        and r.reward_date=((now() at time zone 'Europe/Paris')::date)
      limit 1
    ) as claimed_at;
$$;
revoke all on function public.get_my_daily_reward_status() from public;
grant execute on function public.get_my_daily_reward_status() to authenticated;

create or replace function public.claim_daily_reward(p_ad_event_id bigint)
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

  if exists(
    select 1 from public.game_daily_rewards
    where user_id=v_user and reward_date=v_day
  ) then
    select * into v_wallet from public.wallets where user_id=v_user;
    select streak_days into v_streak from public.profiles where id=v_user;
    return query select false,100::integer,v_wallet.cash,v_streak;
    return;
  end if;

  if not exists(
    select 1 from public.ad_events e
    where e.id=p_ad_event_id
      and e.user_id=v_user
      and e.event_type='impression'
      and e.placement='rewarded_daily'
      and e.occurred_at>=now()-interval '15 minutes'
  ) then
    raise exception 'rewarded_ad_required';
  end if;

  select * into v_wallet from public.wallets where user_id=v_user for update;
  if v_wallet.user_id is null then raise exception 'wallet_missing'; end if;

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
  set cash=cash+100,total_allocated=total_allocated+100,version=version+1,updated_at=now()
  where user_id=v_user;

  insert into public.game_daily_rewards(user_id,reward_date,amount,ad_event_id)
  values(v_user,v_day,100,p_ad_event_id);

  insert into public.allocations(user_id,amount,reason)
  values(v_user,100,'daily_rewarded_collect');

  insert into public.ledger_entries(user_id,entry_type,amount,balance_after,metadata)
  values(
    v_user,'allocation',100,v_wallet.cash+100,
    jsonb_build_object('reason','daily_rewarded_collect','ad_event_id',p_ad_event_id)
  );

  update public.profiles
  set streak_days=v_streak,last_active_on=v_day,updated_at=now()
  where id=v_user;

  return query select true,100::integer,(v_wallet.cash+100)::numeric,v_streak;
end $$;
revoke all on function public.claim_daily_reward(bigint) from public;
grant execute on function public.claim_daily_reward(bigint) to authenticated;

create or replace function private.game_user_wealth(p_user uuid)
returns numeric language sql stable security definer set search_path='' as $$
  select
    coalesce((select w.cash from public.wallets w where w.user_id=p_user),0)
    + coalesce((
      select sum(p.quantity*coalesce(latest.price,p.average_price))
      from public.positions p
      left join lateral (
        select ph.price
        from public.price_history ph
        where ph.asset_id=p.asset_id
        order by ph.observed_at desc limit 1
      ) latest on true
      where p.user_id=p_user and p.asset_id is not null
    ),0)
    + coalesce((
      select sum(
        p.quantity*case
          when m.resolved_outcome is not null then
            case when (p.side::text='yes' and m.resolved_outcome)
                   or (p.side::text='no' and not m.resolved_outcome) then 1 else 0 end
          when p.side::text='yes' then m.yes_probability
          else 1-m.yes_probability
        end
      )
      from public.positions p
      join public.markets m on m.id=p.market_id
      where p.user_id=p_user and p.market_id is not null
    ),0);
$$;
revoke all on function private.game_user_wealth(uuid) from public,anon,authenticated;

create or replace function private.ensure_game_league(p_user uuid)
returns uuid language plpgsql volatile security definer set search_path='' as $$
declare
  v_league uuid;
  v_season uuid;
  v_owner uuid;
begin
  select lm.league_id into v_league
  from public.league_members lm
  join public.leagues l on l.id=lm.league_id
  join public.seasons s on s.id=l.season_id
  where lm.user_id=p_user and s.is_active
  order by lm.joined_at limit 1;

  if v_league is not null then return v_league; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('konsens_flash_league'));
  select id into v_season
  from public.seasons where is_active
  order by starts_at desc limit 1;
  if v_season is null then raise exception 'no_active_season'; end if;

  select id into v_league
  from public.leagues
  where season_id=v_season and name='Ligue Flash'
  order by created_at limit 1;

  if v_league is null then
    select id into v_owner
    from public.profiles
    where role='admin'
    order by created_at limit 1;
    if v_owner is null then v_owner:=p_user; end if;

    insert into public.leagues(name,join_code,owner_id,season_id)
    values(
      'Ligue Flash',
      'FLASH-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
      v_owner,
      v_season
    ) returning id into v_league;
  end if;

  insert into public.league_members(league_id,user_id)
  values(v_league,p_user)
  on conflict do nothing;

  return v_league;
end $$;
revoke all on function private.ensure_game_league(uuid) from public,anon,authenticated;

create or replace function public.get_my_league_leaderboard(p_limit integer default 20)
returns table(
  position integer,
  user_id uuid,
  username text,
  avatar_seed text,
  score numeric,
  is_current_user boolean,
  league_name text
)
language plpgsql volatile security definer set search_path='' as $$
declare
  v_user uuid := (select auth.uid());
  v_league uuid;
  v_name text;
begin
  if v_user is null then raise exception 'unauthenticated'; end if;
  v_league:=private.ensure_game_league(v_user);
  select name into v_name from public.leagues where id=v_league;

  return query
  with scored as (
    select lm.user_id,p.username,p.avatar_seed,private.game_user_wealth(lm.user_id) as score
    from public.league_members lm
    join public.profiles p on p.id=lm.user_id
    where lm.league_id=v_league
  ), ranked as (
    select row_number() over(order by s.score desc,s.user_id)::integer as position,s.*
    from scored s
  )
  select r.position,r.user_id,r.username,r.avatar_seed,r.score,(r.user_id=v_user),v_name
  from ranked r
  order by r.position
  limit greatest(1,least(coalesce(p_limit,20),50));
end $$;
revoke all on function public.get_my_league_leaderboard(integer) from public;
grant execute on function public.get_my_league_leaderboard(integer) to authenticated;

create or replace function public.send_league_reaction(p_target uuid,p_reaction text)
returns bigint language plpgsql volatile security definer set search_path='' as $$
declare
  v_user uuid := (select auth.uid());
  v_league uuid;
  v_id bigint;
  v_actor text;
begin
  if v_user is null then raise exception 'unauthenticated'; end if;
  if p_reaction not in ('😂','🔥','👀','👏','😈','💀') then raise exception 'invalid_reaction'; end if;
  if p_target=v_user then raise exception 'self_reaction'; end if;

  v_league:=private.ensure_game_league(v_user);
  if not exists(
    select 1 from public.league_members
    where league_id=v_league and user_id=p_target
  ) then raise exception 'target_not_in_league'; end if;

  if (
    select count(*) from public.league_reactions
    where actor_id=v_user and created_at>=now()-interval '10 minutes'
  )>=10 then raise exception 'reaction_rate_limit'; end if;

  insert into public.league_reactions(league_id,actor_id,target_id,reaction)
  values(v_league,v_user,p_target,p_reaction)
  returning id into v_id;

  select username into v_actor from public.profiles where id=v_user;
  insert into public.notification_events(user_id,kind,title,body,payload,dedupe_key)
  values(
    p_target,
    'league',
    p_reaction||' Réaction de ligue',
    '@'||coalesce(v_actor,'un joueur')||' t’a envoyé '||p_reaction,
    jsonb_build_object('route','league','actor_id',v_user,'reaction',p_reaction),
    'league-reaction:'||p_target||':'||v_id
  ) on conflict(dedupe_key) where dedupe_key is not null do nothing;

  return v_id;
end $$;
revoke all on function public.send_league_reaction(uuid,text) from public;
grant execute on function public.send_league_reaction(uuid,text) to authenticated;

create or replace function public.get_my_league_reactions(p_limit integer default 20)
returns table(
  id bigint,
  actor_id uuid,
  actor_username text,
  target_id uuid,
  target_username text,
  reaction text,
  created_at timestamptz
)
language plpgsql volatile security definer set search_path='' as $$
declare
  v_user uuid := (select auth.uid());
  v_league uuid;
begin
  if v_user is null then raise exception 'unauthenticated'; end if;
  v_league:=private.ensure_game_league(v_user);

  return query
  select r.id,r.actor_id,a.username,r.target_id,t.username,r.reaction,r.created_at
  from public.league_reactions r
  join public.profiles a on a.id=r.actor_id
  join public.profiles t on t.id=r.target_id
  where r.league_id=v_league
  order by r.created_at desc
  limit greatest(1,least(coalesce(p_limit,20),50));
end $$;
revoke all on function public.get_my_league_reactions(integer) from public;
grant execute on function public.get_my_league_reactions(integer) to authenticated;

create or replace function public.notify_league_big_move()
returns trigger language plpgsql security definer set search_path='' as $$
declare
  v_league uuid;
  v_actor text;
  r record;
begin
  if new.status <> 'executed' or new.credits < 250 then return new; end if;
  select lm.league_id into v_league
  from public.league_members lm
  where lm.user_id=new.user_id
  order by lm.joined_at limit 1;
  if v_league is null then return new; end if;

  select username into v_actor from public.profiles where id=new.user_id;
  for r in
    select user_id from public.league_members
    where league_id=v_league and user_id<>new.user_id
  loop
    insert into public.notification_events(user_id,kind,title,body,payload,dedupe_key)
    values(
      r.user_id,
      'league',
      '👀 Gros move dans ta ligue',
      '@'||coalesce(v_actor,'un joueur')||' vient d’engager '||round(new.credits,0)||' K',
      jsonb_build_object('route','league','actor_id',new.user_id,'order_id',new.id,'credits',new.credits),
      'league-move:'||r.user_id||':'||new.id
    ) on conflict(dedupe_key) where dedupe_key is not null do nothing;
  end loop;
  return new;
end $$;

drop trigger if exists trg_notify_league_big_move on public.trade_orders;
create trigger trg_notify_league_big_move
after insert on public.trade_orders
for each row execute function public.notify_league_big_move();

-- Low-priority house creative keeps the rewarded loop testable until a paid campaign is sold.
insert into public.advertisers(name,slug,website_url,status)
select 'Konsens','konsens-beta','https://konsens.app','active'
where not exists(select 1 from public.advertisers where slug='konsens-beta');

insert into public.ad_campaigns(
  advertiser_id,name,status,placements,priority,frequency_cap_per_session
)
select a.id,'Daily Reward · House','active',array['rewarded_daily']::text[],-100,20
from public.advertisers a
where a.slug='konsens-beta'
  and not exists(
    select 1 from public.ad_campaigns c
    where c.advertiser_id=a.id and c.name='Daily Reward · House'
  );

insert into public.ad_creatives(
  campaign_id,sponsor_name,eyebrow,headline,body,cta_label,destination_url,is_active
)
select
  c.id,
  'Konsens',
  'RÉCOMPENSE DU JOUR',
  '100 Koins t’attendent.',
  'Ce format sera remplacé automatiquement par une campagne sponsorisée quand un annonceur achète le spot quotidien.',
  'Continuer',
  'https://konsens.app',
  true
from public.ad_campaigns c
join public.advertisers a on a.id=c.advertiser_id
where a.slug='konsens-beta'
  and c.name='Daily Reward · House'
  and not exists(select 1 from public.ad_creatives cr where cr.campaign_id=c.id);
