-- Weekly financial-life loop: engagement-gated allowance and visible purchasing-power erosion.
create table public.economy_rules (
  id boolean primary key default true check (id),
  weekly_allowance numeric(14,2) not null default 1000 check (weekly_allowance > 0),
  required_active_days smallint not null default 3 check (required_active_days between 1 and 7),
  annual_inflation_rate numeric(8,6) not null default 0.035 check (annual_inflation_rate between 0 and 1),
  updated_at timestamptz not null default now()
);

insert into public.economy_rules default values on conflict (id) do nothing;

create table public.weekly_cycles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  week_start date not null,
  active_days smallint not null default 0 check (active_days between 0 and 7),
  allowance_amount numeric(14,2) not null default 0 check (allowance_amount >= 0),
  allowance_claimed_at timestamptz,
  opening_cash numeric(14,2) not null default 0 check (opening_cash >= 0),
  closing_cash numeric(14,2) check (closing_cash >= 0),
  inflation_rate_weekly numeric(10,8) not null default 0,
  purchasing_power_loss numeric(14,2) not null default 0 check (purchasing_power_loss >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, week_start)
);

create table public.weekly_activity (
  user_id uuid not null references public.profiles(id) on delete cascade,
  activity_date date not null default current_date,
  created_at timestamptz not null default now(),
  primary key (user_id, activity_date)
);

alter table public.economy_rules enable row level security;
alter table public.weekly_cycles enable row level security;
alter table public.weekly_activity enable row level security;

create policy economy_rules_read on public.economy_rules for select to anon, authenticated using (true);
create policy weekly_cycles_own_read on public.weekly_cycles for select to authenticated using ((select auth.uid()) = user_id);
create policy weekly_cycles_own_insert on public.weekly_cycles for insert to authenticated with check ((select auth.uid()) = user_id);
create policy weekly_cycles_own_update on public.weekly_cycles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy weekly_activity_own_read on public.weekly_activity for select to authenticated using ((select auth.uid()) = user_id);
create policy weekly_activity_own_insert on public.weekly_activity for insert to authenticated with check ((select auth.uid()) = user_id and activity_date = current_date);

grant select on public.economy_rules to anon, authenticated;
grant select, insert, update on public.weekly_cycles to authenticated;
grant select, insert on public.weekly_activity to authenticated;

create index weekly_cycles_user_week_idx on public.weekly_cycles (user_id, week_start desc);
create index weekly_activity_user_date_idx on public.weekly_activity (user_id, activity_date desc);
