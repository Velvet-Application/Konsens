create table public.economy_config (
  id boolean primary key default true check (id),
  currency_name text not null default 'euro virtuel',
  currency_symbol text not null default '€',
  reference_currency char(3) not null default 'EUR',
  reference_ratio numeric(12,6) not null default 1 check (reference_ratio = 1),
  cash_out_enabled boolean not null default false,
  purchasable boolean not null default false,
  updated_at timestamptz not null default now()
);

insert into public.economy_config default values;
alter table public.economy_config enable row level security;
create policy economy_config_read on public.economy_config for select to anon, authenticated using (true);
grant select on public.economy_config to anon, authenticated;

create table public.learning_modules (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  summary text not null,
  concept text not null,
  xp_reward integer not null default 50 check (xp_reward > 0),
  position integer not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.learning_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  module_id uuid not null references public.learning_modules(id) on delete cascade,
  completed_at timestamptz,
  score integer check (score between 0 and 100),
  primary key (user_id, module_id)
);

alter table public.learning_modules enable row level security;
alter table public.learning_progress enable row level security;
create policy learning_modules_read on public.learning_modules for select to anon, authenticated using (is_active);
create policy learning_progress_own_read on public.learning_progress for select to authenticated using ((select auth.uid()) = user_id);
create policy learning_progress_own_insert on public.learning_progress for insert to authenticated with check ((select auth.uid()) = user_id);
create policy learning_progress_own_update on public.learning_progress for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
grant select on public.learning_modules to anon, authenticated;
grant select, insert, update on public.learning_progress to authenticated;

insert into public.learning_modules(slug,title,summary,concept,position) values
('budget','Construire son budget','Comprendre ce qui peut être investi sans fragiliser son quotidien.','capital',1),
('risk','Comprendre le risque','Relier rendement potentiel, incertitude et perte possible.','risk',2),
('etf','Découvrir les ETF','Investir dans un panier diversifié avec un seul produit.','etf',3),
('stocks','Acheter une action','Devenir virtuellement propriétaire d’une fraction d’entreprise.','stock',4),
('predictions','Comprendre une prédiction','Comparer une issue tout-ou-rien avec un placement financier.','prediction',5);
