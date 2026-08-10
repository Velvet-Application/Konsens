create table public.premium_access (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  status text not null default 'trial' check (status in ('trial','active','past_due','cancelled')),
  trial_ends_at timestamptz,
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.public_wallets (
  id uuid primary key default gen_random_uuid(),
  chain text not null,
  address text not null,
  display_name text not null,
  country_code char(2),
  attribution_type text not null default 'pseudonymous' check (attribution_type in ('pseudonymous','self_declared','publicly_attributed')),
  confidence_score smallint not null default 0 check (confidence_score between 0 and 100),
  attribution_source_url text,
  observable_value_eur numeric(20,2),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (chain, address)
);

create table public.wallet_follows (
  user_id uuid not null references public.profiles(id) on delete cascade,
  wallet_id uuid not null references public.public_wallets(id) on delete cascade,
  minimum_alert_eur numeric(14,2) not null default 10000 check (minimum_alert_eur >= 0),
  notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (user_id, wallet_id)
);

create table public.wallet_events (
  id uuid primary key default gen_random_uuid(),
  provider_event_id text not null unique,
  wallet_id uuid not null references public.public_wallets(id) on delete cascade,
  chain text not null,
  transaction_hash text not null,
  event_type text not null check (event_type in ('transfer','swap','defi_deposit','defi_withdrawal','unknown')),
  direction text not null check (direction in ('in','out','internal')),
  asset_symbol text,
  asset_amount numeric(30,10),
  estimated_value_eur numeric(20,2),
  block_time timestamptz,
  explorer_url text,
  raw_event jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.reality_comparisons (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  simulated_action jsonb not null,
  simulated_value_eur numeric(14,2) not null,
  real_market_value_eur numeric(14,2) not null,
  network_fees_eur numeric(14,2) not null default 0,
  slippage_eur numeric(14,2) not null default 0,
  compared_at timestamptz not null default now()
);

alter table public.premium_access enable row level security;
alter table public.public_wallets enable row level security;
alter table public.wallet_follows enable row level security;
alter table public.wallet_events enable row level security;
alter table public.reality_comparisons enable row level security;

create policy premium_access_own_read on public.premium_access for select to authenticated using ((select auth.uid()) = user_id);
create policy public_wallets_authenticated_read on public.public_wallets for select to authenticated using (is_active);
create policy wallet_follows_own_read on public.wallet_follows for select to authenticated using ((select auth.uid()) = user_id);
create policy wallet_follows_own_insert on public.wallet_follows for insert to authenticated with check ((select auth.uid()) = user_id and (select count(*) from public.wallet_follows f where f.user_id = (select auth.uid())) < 10);
create policy wallet_follows_own_update on public.wallet_follows for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy wallet_follows_own_delete on public.wallet_follows for delete to authenticated using ((select auth.uid()) = user_id);
create policy followed_wallet_events_read on public.wallet_events for select to authenticated using (exists (select 1 from public.wallet_follows f where f.wallet_id = wallet_events.wallet_id and f.user_id = (select auth.uid())));
create policy comparisons_own_read on public.reality_comparisons for select to authenticated using ((select auth.uid()) = user_id);

grant select on public.premium_access, public.public_wallets, public.wallet_events, public.reality_comparisons to authenticated;
grant select, insert, update, delete on public.wallet_follows to authenticated;

create index wallet_follows_user_idx on public.wallet_follows (user_id);
create index wallet_events_wallet_time_idx on public.wallet_events (wallet_id, block_time desc);
create index reality_comparisons_user_time_idx on public.reality_comparisons (user_id, compared_at desc);
