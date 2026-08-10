-- Konsens game layer. Rewards are XP/cosmetics only; financial outcomes stay simulated.
create table public.game_missions (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text not null,
  mission_type text not null check (mission_type in ('daily','weekly','seasonal')),
  target integer not null check (target > 0),
  xp_reward integer not null check (xp_reward >= 0),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  active boolean not null default true
);

create table public.mission_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  mission_id uuid not null references public.game_missions(id) on delete cascade,
  progress integer not null default 0 check (progress >= 0),
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, mission_id)
);

create table public.duels (
  id uuid primary key default gen_random_uuid(),
  challenger_id uuid not null references public.profiles(id) on delete cascade,
  opponent_id uuid not null references public.profiles(id) on delete cascade,
  market_id uuid not null references public.markets(id) on delete cascade,
  virtual_stake numeric(14,2) not null check (virtual_stake > 0),
  challenger_side text check (challenger_side in ('yes','no')),
  opponent_side text check (opponent_side in ('yes','no')),
  status text not null default 'pending' check (status in ('pending','accepted','resolved','declined','cancelled')),
  winner_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  check (challenger_id <> opponent_id)
);

alter table public.game_missions enable row level security;
alter table public.mission_progress enable row level security;
alter table public.duels enable row level security;

create policy "missions are publicly readable" on public.game_missions for select using (active = true);
create policy "users read own mission progress" on public.mission_progress for select using (auth.uid() = user_id);
create policy "users create own mission progress" on public.mission_progress for insert with check (auth.uid() = user_id);
create policy "users update own mission progress" on public.mission_progress for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "duel participants can read" on public.duels for select using (auth.uid() in (challenger_id, opponent_id));
create policy "users can create their challenge" on public.duels for insert with check (auth.uid() = challenger_id);
create policy "participants can update duel" on public.duels for update using (auth.uid() in (challenger_id, opponent_id)) with check (auth.uid() in (challenger_id, opponent_id));

insert into public.game_missions (slug,title,description,mission_type,target,xp_reward,ends_at) values
('three-markets','Joue 3 marchés différents','Analyse et prends position sur trois thèmes distincts.','daily',3,80,now() + interval '1 day'),
('risk-discipline','Garde tes mises sous 5 %','Réalise cinq prédictions sans dépasser 5 % de ton solde par mise.','weekly',5,250,now() + interval '7 days'),
('learn-then-play','Apprends puis décide','Termine une leçon avant de jouer le marché associé.','daily',1,50,now() + interval '1 day')
on conflict (slug) do nothing;
