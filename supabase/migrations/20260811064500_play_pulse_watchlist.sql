create table if not exists public.market_watchlist (
  user_id uuid not null references auth.users(id) on delete cascade,
  market_id uuid not null references public.markets(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, market_id)
);

alter table public.market_watchlist enable row level security;

drop policy if exists market_watchlist_read_own on public.market_watchlist;
create policy market_watchlist_read_own on public.market_watchlist for select to authenticated using (auth.uid() = user_id);
drop policy if exists market_watchlist_insert_own on public.market_watchlist;
create policy market_watchlist_insert_own on public.market_watchlist for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists market_watchlist_delete_own on public.market_watchlist;
create policy market_watchlist_delete_own on public.market_watchlist for delete to authenticated using (auth.uid() = user_id);

grant select, insert, delete on public.market_watchlist to authenticated;

create or replace function public.get_market_movers(p_limit integer default 12)
returns table (
  market_id uuid,
  movement_24h numeric,
  volume_24h numeric,
  trades_24h bigint
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select
    m.id,
    round(((m.yes_probability - coalesce(h.past_probability, m.yes_probability)) * 100)::numeric, 1) as movement_24h,
    round(coalesce(v.volume_24h, 0)::numeric, 0) as volume_24h,
    coalesce(v.trades_24h, 0)::bigint as trades_24h
  from public.markets m
  left join lateral (
    select mph.yes_probability as past_probability
    from public.market_probability_history mph
    where mph.market_id = m.id
      and mph.observed_at <= now() - interval '24 hours'
    order by mph.observed_at desc
    limit 1
  ) h on true
  left join lateral (
    select sum(o.credits) as volume_24h, count(*) as trades_24h
    from public.trade_orders o
    where o.market_id = m.id
      and o.status = 'executed'
      and coalesce(o.executed_at, o.created_at) >= now() - interval '24 hours'
  ) v on true
  where m.status = 'open'
  order by abs((m.yes_probability - coalesce(h.past_probability, m.yes_probability)) * 100) desc,
           coalesce(v.volume_24h, 0) desc,
           m.created_at desc
  limit least(greatest(coalesce(p_limit, 12), 1), 50);
$$;

grant execute on function public.get_market_movers(integer) to authenticated;

create or replace function public.get_market_activity(p_market_id uuid default null, p_limit integer default 30)
returns table (
  market_id uuid,
  question text,
  category text,
  outcome text,
  side text,
  trade_count bigint,
  credits numeric,
  occurred_at timestamptz
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select
    o.market_id,
    m.question,
    m.category,
    o.outcome::text,
    o.side::text,
    count(*)::bigint as trade_count,
    round(sum(o.credits)::numeric, 0) as credits,
    max(coalesce(o.executed_at, o.created_at)) as occurred_at
  from public.trade_orders o
  join public.markets m on m.id = o.market_id
  where o.status = 'executed'
    and o.market_id is not null
    and (p_market_id is null or o.market_id = p_market_id)
  group by o.market_id, m.question, m.category, o.outcome, o.side,
           date_trunc('minute', coalesce(o.executed_at, o.created_at))
  order by occurred_at desc
  limit least(greatest(coalesce(p_limit, 30), 1), 100);
$$;

grant execute on function public.get_market_activity(uuid, integer) to authenticated;
