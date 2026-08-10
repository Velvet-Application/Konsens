-- Konsens monetization foundation: contextual sponsorship, Connect SDK and aggregate Signals API.
alter table public.profiles add column if not exists subscription_tier text not null default 'free' check (subscription_tier in ('free','plus'));
alter table public.profiles add column if not exists ad_personalization_consent boolean not null default false;
alter table public.profiles add column if not exists monetization_updated_at timestamptz;

create table if not exists public.advertisers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,62}$'),
  website_url text,
  billing_email text,
  status text not null default 'active' check (status in ('active','paused','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ad_slots (
  id uuid primary key default gen_random_uuid(),
  slot_key text not null unique,
  placement text not null check (placement in ('feed_native','challenge_sponsor','post_prediction')),
  description text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.ad_campaigns (
  id uuid primary key default gen_random_uuid(),
  advertiser_id uuid not null references public.advertisers(id) on delete cascade,
  name text not null,
  status text not null default 'draft' check (status in ('draft','active','paused','completed','archived')),
  placements text[] not null default array['feed_native']::text[] check (cardinality(placements) > 0),
  categories text[] not null default '{}'::text[],
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  budget_cents bigint check (budget_cents is null or budget_cents >= 0),
  cpm_cents integer check (cpm_cents is null or cpm_cents >= 0),
  priority integer not null default 0,
  daily_impression_cap integer check (daily_impression_cap is null or daily_impression_cap > 0),
  frequency_cap_per_session integer not null default 2 check (frequency_cap_per_session between 1 and 20),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create table if not exists public.ad_creatives (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.ad_campaigns(id) on delete cascade,
  sponsor_name text not null,
  eyebrow text not null default 'SPONSORISÉ',
  headline text not null check (char_length(headline) between 3 and 140),
  body text check (body is null or char_length(body) <= 280),
  cta_label text not null default 'Découvrir' check (char_length(cta_label) between 1 and 40),
  destination_url text not null,
  image_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ad_events (
  id bigint generated always as identity primary key,
  campaign_id uuid not null references public.ad_campaigns(id) on delete cascade,
  creative_id uuid not null references public.ad_creatives(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  session_id text not null check (char_length(session_id) between 8 and 100),
  event_type text not null check (event_type in ('impression','click','conversion')),
  placement text not null check (placement in ('feed_native','challenge_sponsor','post_prediction')),
  slot_key text,
  resource_id text,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create table if not exists public.sdk_clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,62}$'),
  api_key_hash text not null unique,
  plan text not null default 'developer' check (plan in ('developer','starter','pro','business','enterprise')),
  status text not null default 'active' check (status in ('active','paused','revoked')),
  monthly_event_limit bigint not null default 10000 check (monthly_event_limit > 0),
  allowed_origins text[] not null default '{}'::text[],
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sdk_events (
  id bigint generated always as identity primary key,
  client_id uuid not null references public.sdk_clients(id) on delete cascade,
  event_type text not null check (event_type in ('render','signal_read','prediction_intent','error')),
  origin text not null,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

insert into public.ad_slots(slot_key,placement,description) values
  ('home_after_hero','feed_native','Spot natif après le hero de l’accueil'),
  ('challenges_every_fifth','feed_native','Spot natif après chaque groupe de challenges'),
  ('challenge_presented_by','challenge_sponsor','Mention « challenge présenté par »'),
  ('post_prediction','post_prediction','Spot après validation d’une prédiction'),
  ('app_contextual_native','feed_native','Spot contextuel natif injecté dans la version gratuite Web/PWA')
on conflict (slot_key) do update set placement=excluded.placement, description=excluded.description, is_active=true;

create index if not exists ad_campaigns_active_idx on public.ad_campaigns(status, starts_at, ends_at, priority desc);
create index if not exists ad_events_campaign_time_idx on public.ad_events(campaign_id, occurred_at desc);
create index if not exists ad_events_session_idx on public.ad_events(session_id, campaign_id, occurred_at desc);
create index if not exists sdk_events_client_time_idx on public.sdk_events(client_id, occurred_at desc);

alter table public.advertisers enable row level security;
alter table public.ad_slots enable row level security;
alter table public.ad_campaigns enable row level security;
alter table public.ad_creatives enable row level security;
alter table public.ad_events enable row level security;
alter table public.sdk_clients enable row level security;
alter table public.sdk_events enable row level security;

create policy advertisers_admin_select on public.advertisers for select to authenticated using ((select private.is_admin()));
create policy advertisers_admin_write on public.advertisers for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy ad_slots_admin_select on public.ad_slots for select to authenticated using ((select private.is_admin()));
create policy ad_slots_admin_write on public.ad_slots for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy ad_campaigns_admin_select on public.ad_campaigns for select to authenticated using ((select private.is_admin()));
create policy ad_campaigns_admin_write on public.ad_campaigns for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy ad_creatives_admin_select on public.ad_creatives for select to authenticated using ((select private.is_admin()));
create policy ad_creatives_admin_write on public.ad_creatives for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy ad_events_admin_select on public.ad_events for select to authenticated using ((select private.is_admin()));
create policy sdk_clients_admin_select on public.sdk_clients for select to authenticated using ((select private.is_admin()));
create policy sdk_clients_admin_write on public.sdk_clients for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy sdk_events_admin_select on public.sdk_events for select to authenticated using ((select private.is_admin()));

revoke all on public.advertisers, public.ad_slots, public.ad_campaigns, public.ad_creatives, public.ad_events, public.sdk_clients, public.sdk_events from anon, authenticated;
grant select, insert, update, delete on public.advertisers, public.ad_slots, public.ad_campaigns, public.ad_creatives, public.sdk_clients to authenticated;
grant select on public.ad_events, public.sdk_events to authenticated;

create or replace function public.get_active_ad(p_placement text,p_category text default null,p_session_id text default null)
returns table(campaign_id uuid,creative_id uuid,sponsor_name text,eyebrow text,headline text,body text,cta_label text,destination_url text,image_url text,placement text)
language sql volatile security definer set search_path = '' as $$
  select c.id,cr.id,cr.sponsor_name,cr.eyebrow,cr.headline,cr.body,cr.cta_label,cr.destination_url,cr.image_url,p_placement
  from public.ad_campaigns c
  join public.advertisers a on a.id=c.advertiser_id and a.status='active'
  join public.ad_creatives cr on cr.campaign_id=c.id and cr.is_active
  where c.status='active' and p_placement=any(c.placements) and c.starts_at<=now() and (c.ends_at is null or c.ends_at>now())
    and (cardinality(c.categories)=0 or p_category is null or p_category=any(c.categories))
    and (c.daily_impression_cap is null or (select count(*) from public.ad_events e where e.campaign_id=c.id and e.event_type='impression' and e.occurred_at>=date_trunc('day',now()))<c.daily_impression_cap)
    and (p_session_id is null or (select count(*) from public.ad_events e where e.campaign_id=c.id and e.session_id=p_session_id and e.event_type='impression')<c.frequency_cap_per_session)
  order by c.priority desc,c.starts_at desc,cr.created_at asc limit 1
$$;
revoke all on function public.get_active_ad(text,text,text) from public;
grant execute on function public.get_active_ad(text,text,text) to anon,authenticated;

create or replace function public.track_ad_event(p_campaign_id uuid,p_creative_id uuid,p_event_type text,p_placement text,p_session_id text,p_slot_key text default null,p_resource_id text default null,p_metadata jsonb default '{}'::jsonb)
returns bigint language plpgsql volatile security definer set search_path = '' as $$
declare v_id bigint;
begin
  if p_event_type not in ('impression','click','conversion') then raise exception 'invalid_event_type'; end if;
  if p_placement not in ('feed_native','challenge_sponsor','post_prediction') then raise exception 'invalid_placement'; end if;
  if char_length(coalesce(p_session_id,'')) not between 8 and 100 then raise exception 'invalid_session'; end if;
  if not exists(select 1 from public.ad_creatives where id=p_creative_id and campaign_id=p_campaign_id and is_active) then raise exception 'invalid_creative'; end if;
  insert into public.ad_events(campaign_id,creative_id,user_id,session_id,event_type,placement,slot_key,resource_id,metadata)
  values(p_campaign_id,p_creative_id,(select auth.uid()),p_session_id,p_event_type,p_placement,p_slot_key,p_resource_id,coalesce(p_metadata,'{}'::jsonb)) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.track_ad_event(uuid,uuid,text,text,text,text,text,jsonb) from public;
grant execute on function public.track_ad_event(uuid,uuid,text,text,text,text,text,jsonb) to anon,authenticated;

create or replace function public.get_challenge_signal(p_challenge_id uuid)
returns table(challenge_id uuid,question text,yes_count bigint,no_count bigint,total_count bigint,yes_ratio numeric)
language sql stable security definer set search_path = '' as $$
  select d.id,d.question,count(*) filter(where a.answer is true)::bigint,count(*) filter(where a.answer is false)::bigint,count(a.user_id)::bigint,
    case when count(a.user_id)=0 then 0::numeric else round((count(*) filter(where a.answer is true))::numeric/count(a.user_id),4) end
  from public.daily_challenges d left join public.challenge_answers a on a.challenge_id=d.id where d.id=p_challenge_id group by d.id,d.question
$$;
revoke all on function public.get_challenge_signal(uuid) from public;
grant execute on function public.get_challenge_signal(uuid) to anon,authenticated;

create or replace function public.create_sdk_client(p_name text,p_slug text,p_plan text default 'developer',p_monthly_event_limit bigint default 10000,p_allowed_origins text[] default '{}'::text[])
returns table(client_id uuid,api_key text) language plpgsql volatile security definer set search_path = '' as $$
declare v_id uuid; v_key text;
begin
  if not (select private.is_admin()) then raise exception 'forbidden'; end if;
  if p_plan not in ('developer','starter','pro','business','enterprise') then raise exception 'invalid_plan'; end if;
  v_key:='ks_live_'||replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
  insert into public.sdk_clients(name,slug,api_key_hash,plan,monthly_event_limit,allowed_origins,created_by)
  values(p_name,p_slug,extensions.encode(extensions.digest(v_key,'sha256'),'hex'),p_plan,p_monthly_event_limit,p_allowed_origins,(select auth.uid())) returning id into v_id;
  return query select v_id,v_key;
end $$;
revoke all on function public.create_sdk_client(text,text,text,bigint,text[]) from public,anon;
grant execute on function public.create_sdk_client(text,text,text,bigint,text[]) to authenticated;

create or replace function public.register_sdk_event(p_api_key text,p_event_type text,p_origin text,p_metadata jsonb default '{}'::jsonb)
returns table(client_id uuid,plan text,remaining_events bigint) language plpgsql volatile security definer set search_path = '' as $$
declare v_client public.sdk_clients%rowtype; v_used bigint;
begin
  if p_event_type not in ('render','signal_read','prediction_intent','error') then raise exception 'invalid_event_type'; end if;
  select * into v_client from public.sdk_clients where api_key_hash=extensions.encode(extensions.digest(p_api_key,'sha256'),'hex') and status='active';
  if v_client.id is null then raise exception 'invalid_api_key'; end if;
  if not ('*'=any(v_client.allowed_origins) or p_origin=any(v_client.allowed_origins)) then raise exception 'origin_not_allowed'; end if;
  select count(*) into v_used from public.sdk_events where client_id=v_client.id and occurred_at>=date_trunc('month',now());
  if v_used>=v_client.monthly_event_limit then raise exception 'monthly_limit_reached'; end if;
  insert into public.sdk_events(client_id,event_type,origin,metadata) values(v_client.id,p_event_type,p_origin,coalesce(p_metadata,'{}'::jsonb));
  return query select v_client.id,v_client.plan,greatest(v_client.monthly_event_limit-v_used-1,0);
end $$;
revoke all on function public.register_sdk_event(text,text,text,jsonb) from public;
grant execute on function public.register_sdk_event(text,text,text,jsonb) to anon,authenticated;
