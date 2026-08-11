create table if not exists public.asset_watchlist (
  user_id uuid not null references auth.users(id) on delete cascade,
  asset_id uuid not null references public.assets(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, asset_id)
);

alter table public.asset_watchlist enable row level security;

drop policy if exists asset_watchlist_read_own on public.asset_watchlist;
create policy asset_watchlist_read_own on public.asset_watchlist for select to authenticated using (auth.uid() = user_id);
drop policy if exists asset_watchlist_insert_own on public.asset_watchlist;
create policy asset_watchlist_insert_own on public.asset_watchlist for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists asset_watchlist_delete_own on public.asset_watchlist;
create policy asset_watchlist_delete_own on public.asset_watchlist for delete to authenticated using (auth.uid() = user_id);

grant select, insert, delete on public.asset_watchlist to authenticated;
