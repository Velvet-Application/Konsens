-- Clean beta: no seeded content or balances. Credits have no monetary value.
alter table public.profiles add column if not exists first_name text;
alter table public.profiles add column if not exists last_name text;
alter table public.profiles add column if not exists birth_date date;
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists role text not null default 'user' check (role in ('user','moderator','admin'));
alter table public.profiles add column if not exists onboarding_completed_at timestamptz;

create table public.deals (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  question text not null check (char_length(question) between 15 and 280),
  category text not null check (category in ('quotidien','sport','actualite','finance','culture')),
  closes_at timestamptz not null,
  resolution_source_url text not null,
  status text not null default 'pending' check (status in ('pending','approved','open','closed','resolved','rejected','cancelled')),
  resolved_outcome boolean,
  moderation_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (closes_at > created_at)
);

create table public.challenge_drafts (
  id uuid primary key default gen_random_uuid(),
  question text not null check (char_length(question) between 15 and 280),
  category text not null,
  resolution_rule text not null,
  resolution_source_url text not null,
  source_title text not null,
  source_published_at timestamptz,
  closes_at timestamptz not null,
  generation_model text not null,
  generation_batch_id uuid not null,
  status text not null default 'pending_review' check (status in ('pending_review','approved','rejected','published')),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.deals enable row level security;
alter table public.challenge_drafts enable row level security;

create or replace function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = (select auth.uid()) and role in ('admin','moderator'))
$$;
revoke all on function private.is_admin() from public, anon, authenticated;
grant execute on function private.is_admin() to authenticated;

create policy deals_visible on public.deals for select to authenticated using (status in ('approved','open','closed','resolved') or creator_id = (select auth.uid()) or (select private.is_admin()));
create policy deals_create_own on public.deals for insert to authenticated with check (creator_id = (select auth.uid()) and status = 'pending');
create policy deals_admin_update on public.deals for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy challenge_drafts_admin_read on public.challenge_drafts for select to authenticated using ((select private.is_admin()));
create policy challenge_drafts_admin_update on public.challenge_drafts for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));

grant select, insert on public.deals to authenticated;
grant update on public.deals to authenticated;
grant select, update on public.challenge_drafts to authenticated;
revoke update on public.profiles from authenticated;
grant update(username,display_name,first_name,last_name,birth_date,email,onboarding_completed_at,last_active_on,updated_at) on public.profiles to authenticated;
drop policy if exists profiles_read on public.profiles;
create policy profiles_own_or_admin_read on public.profiles for select to authenticated using (id = (select auth.uid()) or (select private.is_admin()));

-- Remove every fabricated demo record while keeping registered accounts.
delete from public.challenge_answers;
delete from public.daily_challenges;
delete from public.mission_progress;
delete from public.game_missions;
delete from public.duels;
delete from public.ledger_entries;
delete from public.trade_orders;
delete from public.positions;
delete from public.price_history;
delete from public.assets;
delete from public.markets;
delete from public.allocations;
delete from public.wallet_events;
delete from public.wallet_follows;
delete from public.public_wallets;
update public.wallets set cash = 0, total_allocated = 0, version = version + 1, updated_at = now();
update public.profiles set onboarding_completed_at = null, first_name = null, last_name = null, birth_date = null, email = null, xp = 0, streak_days = 0;

create or replace function private.create_profile_for_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_username text;
begin
  v_username := 'joueur_' || substr(replace(new.id::text,'-',''),1,8);
  insert into public.profiles(id,username,display_name,avatar_seed,email)
  values(new.id,v_username,v_username,upper(substr(v_username,1,1)),new.email);
  insert into public.wallets(user_id,cash,total_allocated) values(new.id,0,0);
  return new;
end $$;
revoke all on function private.create_profile_for_user() from public, anon, authenticated;

create index deals_creator_status_idx on public.deals (creator_id,status,created_at desc);
create index challenge_drafts_status_idx on public.challenge_drafts (status,created_at desc);
