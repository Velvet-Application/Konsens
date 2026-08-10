-- Konsens beta foundation. Designed for a dedicated Supabase project.
create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create type public.asset_kind as enum ('stock','etf','index');
create type public.market_status as enum ('draft','open','closed','resolved','cancelled');
create type public.trade_side as enum ('buy','sell');
create type public.position_side as enum ('asset','yes','no');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[A-Za-z0-9_]{3,24}$'),
  display_name text not null check (char_length(display_name) between 1 and 60),
  avatar_seed text not null default 'K',
  xp integer not null default 0 check (xp >= 0),
  streak_days integer not null default 0 check (streak_days >= 0),
  last_active_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  is_active boolean not null default false,
  check (ends_at > starts_at)
);

create table public.wallets (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  cash numeric(18,4) not null default 10000 check (cash >= 0),
  total_allocated numeric(18,4) not null default 10000 check (total_allocated >= 0),
  version bigint not null default 0,
  updated_at timestamptz not null default now()
);

create table public.allocations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount numeric(18,4) not null check (amount > 0),
  reason text not null,
  season_id uuid references public.seasons(id),
  created_at timestamptz not null default now()
);

create table public.assets (
  id uuid primary key default gen_random_uuid(),
  symbol text not null unique,
  name text not null,
  kind public.asset_kind not null,
  currency char(3) not null default 'EUR',
  external_ref text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.price_history (
  asset_id uuid not null references public.assets(id) on delete cascade,
  observed_at timestamptz not null,
  price numeric(18,6) not null check (price > 0),
  source text not null,
  primary key (asset_id, observed_at)
);

create table public.markets (
  id uuid primary key default gen_random_uuid(),
  question text not null check (char_length(question) between 10 and 280),
  category text not null,
  resolution_rules text not null,
  closes_at timestamptz not null,
  status public.market_status not null default 'draft',
  yes_probability numeric(6,5) not null default 0.5 check (yes_probability between 0.01 and 0.99),
  liquidity_parameter numeric(18,4) not null default 1000 check (liquidity_parameter > 0),
  resolved_outcome boolean,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.positions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  asset_id uuid references public.assets(id),
  market_id uuid references public.markets(id),
  side public.position_side not null,
  quantity numeric(18,6) not null default 0 check (quantity >= 0),
  average_price numeric(18,6) not null default 0 check (average_price >= 0),
  updated_at timestamptz not null default now(),
  check ((asset_id is not null and market_id is null and side = 'asset') or (asset_id is null and market_id is not null and side in ('yes','no')))
);
create unique index positions_asset_unique on public.positions(user_id, asset_id) where asset_id is not null;
create unique index positions_market_unique on public.positions(user_id, market_id, side) where market_id is not null;

create table public.trade_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  asset_id uuid references public.assets(id),
  market_id uuid references public.markets(id),
  side public.trade_side not null,
  outcome public.position_side,
  credits numeric(18,4) not null check (credits > 0),
  idempotency_key uuid not null,
  status text not null default 'pending' check (status in ('pending','executed','rejected')),
  execution_price numeric(18,6),
  rejection_reason text,
  created_at timestamptz not null default now(),
  executed_at timestamptz,
  unique (user_id, idempotency_key),
  check ((asset_id is not null and market_id is null and outcome is null) or (asset_id is null and market_id is not null and outcome in ('yes','no')))
);

create table public.ledger_entries (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete restrict,
  order_id uuid references public.trade_orders(id) on delete restrict,
  entry_type text not null check (entry_type in ('allocation','trade_debit','trade_credit','settlement','adjustment')),
  amount numeric(18,4) not null,
  balance_after numeric(18,4) not null check (balance_after >= 0),
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table public.leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text not null unique,
  owner_id uuid not null references public.profiles(id),
  season_id uuid not null references public.seasons(id),
  created_at timestamptz not null default now()
);
create table public.league_members (
  league_id uuid not null references public.leagues(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (league_id, user_id)
);

create table public.daily_challenges (
  id uuid primary key default gen_random_uuid(),
  question text not null,
  opens_at timestamptz not null,
  closes_at timestamptz not null,
  xp_reward integer not null default 40 check (xp_reward > 0),
  resolved_outcome boolean,
  check (closes_at > opens_at)
);
create table public.challenge_answers (
  challenge_id uuid not null references public.daily_challenges(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  answer boolean not null,
  answered_at timestamptz not null default now(),
  primary key (challenge_id, user_id)
);

create index allocations_user_idx on public.allocations(user_id, created_at desc);
create index ledger_user_idx on public.ledger_entries(user_id, created_at desc);
create index orders_user_idx on public.trade_orders(user_id, created_at desc);
create index league_members_user_idx on public.league_members(user_id);
create index markets_open_idx on public.markets(closes_at) where status = 'open';

create or replace function private.is_league_member(check_user uuid, check_league uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.league_members where user_id = check_user and league_id = check_league)
$$;
revoke all on function private.is_league_member(uuid,uuid) from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_league_member(uuid,uuid) to authenticated;

create or replace function private.create_profile_for_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_username text;
begin
  v_username := coalesce(nullif(new.raw_user_meta_data ->> 'username',''), 'joueur_' || substr(replace(new.id::text,'-',''),1,8));
  insert into public.profiles(id, username, display_name, avatar_seed)
  values(new.id, v_username, coalesce(nullif(new.raw_user_meta_data ->> 'display_name',''), v_username), upper(substr(v_username,1,1)));
  insert into public.wallets(user_id) values(new.id);
  insert into public.allocations(user_id, amount, reason) values(new.id, 10000, 'initial_beta');
  insert into public.ledger_entries(user_id, entry_type, amount, balance_after, metadata)
  values(new.id, 'allocation', 10000, 10000, '{"reason":"initial_beta"}');
  return new;
end $$;
revoke all on function private.create_profile_for_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users for each row execute function private.create_profile_for_user();

create or replace function private.execute_trade_order() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_wallet public.wallets%rowtype; v_price numeric(18,6); v_quantity numeric(18,6); v_position_side public.position_side;
begin
  if new.user_id <> (select auth.uid()) then raise exception 'unauthorized'; end if;
  select * into v_wallet from public.wallets where user_id = new.user_id for update;
  if new.side = 'buy' and v_wallet.cash < new.credits then raise exception 'insufficient_credits'; end if;

  if new.asset_id is not null then
    select price into v_price from public.price_history where asset_id = new.asset_id order by observed_at desc limit 1;
    v_position_side := 'asset';
  else
    select case when new.outcome = 'yes' then yes_probability else 1-yes_probability end
      into v_price from public.markets where id = new.market_id and status = 'open' and closes_at > now();
    v_position_side := new.outcome;
  end if;
  if v_price is null or v_price <= 0 then raise exception 'market_unavailable'; end if;
  v_quantity := round(new.credits / v_price, 6);

  if new.side = 'buy' then
    update public.wallets set cash = cash - new.credits, version = version + 1, updated_at = now() where user_id = new.user_id;
    if new.asset_id is not null then
      insert into public.positions(user_id, asset_id, market_id, side, quantity, average_price)
        values(new.user_id,new.asset_id,null,v_position_side,v_quantity,v_price)
        on conflict (user_id, asset_id) where asset_id is not null do update
        set average_price=((public.positions.quantity*public.positions.average_price)+(excluded.quantity*excluded.average_price))/(public.positions.quantity+excluded.quantity), quantity=public.positions.quantity+excluded.quantity, updated_at=now();
    else
      insert into public.positions(user_id, asset_id, market_id, side, quantity, average_price)
      values(new.user_id,null,new.market_id,v_position_side,v_quantity,v_price)
      on conflict (user_id, market_id, side) where market_id is not null do update
      set average_price=((public.positions.quantity*public.positions.average_price)+(excluded.quantity*excluded.average_price))/(public.positions.quantity+excluded.quantity), quantity=public.positions.quantity+excluded.quantity, updated_at=now();
    end if;
    insert into public.ledger_entries(user_id,order_id,entry_type,amount,balance_after,metadata)
      values(new.user_id,new.id,'trade_debit',-new.credits,v_wallet.cash-new.credits,jsonb_build_object('price',v_price,'quantity',v_quantity));
  else
    raise exception 'sell_not_enabled_in_beta';
  end if;
  new.status := 'executed'; new.execution_price := v_price; new.executed_at := now();
  return new;
exception when others then
  new.status := 'rejected'; new.rejection_reason := sqlerrm; return new;
end $$;
revoke all on function private.execute_trade_order() from public, anon, authenticated;
create trigger execute_trade_before_insert before insert on public.trade_orders for each row execute function private.execute_trade_order();

alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.allocations enable row level security;
alter table public.assets enable row level security;
alter table public.price_history enable row level security;
alter table public.markets enable row level security;
alter table public.positions enable row level security;
alter table public.trade_orders enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.seasons enable row level security;
alter table public.leagues enable row level security;
alter table public.league_members enable row level security;
alter table public.daily_challenges enable row level security;
alter table public.challenge_answers enable row level security;

create policy profiles_read on public.profiles for select to authenticated using (true);
create policy profiles_update_own on public.profiles for update to authenticated using ((select auth.uid())=id) with check ((select auth.uid())=id);
create policy wallets_read_own on public.wallets for select to authenticated using ((select auth.uid())=user_id);
create policy allocations_read_own on public.allocations for select to authenticated using ((select auth.uid())=user_id);
create policy assets_read on public.assets for select to authenticated using (is_active);
create policy prices_read on public.price_history for select to authenticated using (true);
create policy markets_read on public.markets for select to authenticated using (status in ('open','closed','resolved'));
create policy positions_read on public.positions for select to authenticated using (true);
create policy orders_read_own on public.trade_orders for select to authenticated using ((select auth.uid())=user_id);
create policy orders_insert_own on public.trade_orders for insert to authenticated with check ((select auth.uid())=user_id);
create policy ledger_read_own on public.ledger_entries for select to authenticated using ((select auth.uid())=user_id);
create policy seasons_read on public.seasons for select to authenticated using (true);
create policy leagues_read_member on public.leagues for select to authenticated using ((select private.is_league_member((select auth.uid()),id)) or owner_id=(select auth.uid()));
create policy league_members_read_member on public.league_members for select to authenticated using ((select private.is_league_member((select auth.uid()),league_id)));
create policy challenges_read on public.daily_challenges for select to authenticated using (true);
create policy answers_read_own on public.challenge_answers for select to authenticated using ((select auth.uid())=user_id);
create policy answers_insert_own on public.challenge_answers for insert to authenticated with check ((select auth.uid())=user_id and answered_at between (select opens_at from public.daily_challenges where id=challenge_id) and (select closes_at from public.daily_challenges where id=challenge_id));

grant usage on schema public to authenticated;
grant select on public.profiles,public.wallets,public.allocations,public.assets,public.price_history,public.markets,public.positions,public.trade_orders,public.ledger_entries,public.seasons,public.leagues,public.league_members,public.daily_challenges,public.challenge_answers to authenticated;
grant update(display_name,avatar_seed,last_active_on,updated_at) on public.profiles to authenticated;
grant insert on public.trade_orders,public.challenge_answers to authenticated;
revoke all on public.ledger_entries from anon;

insert into public.seasons(name, starts_at, ends_at, is_active) values ('Saison 01', date_trunc('day',now()), date_trunc('day',now()) + interval '28 days', true);
insert into public.assets(symbol,name,kind,currency,external_ref) values
('AIR','Airbus','stock','EUR','AIR.PA'),('MC','LVMH','stock','EUR','MC.PA'),('CW8','Amundi MSCI World','etf','EUR','CW8.PA'),('PX1','CAC 40','index','EUR','PX1');
insert into public.price_history(asset_id,observed_at,price,source) select id,now(),case symbol when 'AIR' then 182.40 when 'MC' then 521.20 when 'CW8' then 612.50 else 8215.00 end,'seed' from public.assets;
insert into public.markets(question,category,resolution_rules,closes_at,status,yes_probability) values
('La BCE baissera-t-elle ses taux avant le 31 décembre ?','Macro','Résolution selon la première décision officielle publiée par la BCE.',now()+interval '120 days','open',0.63),
('Le CAC 40 terminera-t-il la semaine au-dessus de 8 200 points ?','Marchés','Cours de clôture officiel Euronext le dernier jour de cotation de la semaine.',now()+interval '5 days','open',0.46),
('Apple dépassera-t-elle 4 000 Md$ de capitalisation cette année ?','Tech','Capitalisation de clôture constatée par le fournisseur de données retenu.',now()+interval '140 days','open',0.57);
insert into public.daily_challenges(question,opens_at,closes_at,xp_reward) values ('L’inflation française repassera-t-elle sous 2 % avant octobre ?',date_trunc('day',now()),date_trunc('day',now())+interval '20 hours',40);
