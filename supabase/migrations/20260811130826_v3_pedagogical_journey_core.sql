-- Konsens V3 — pedagogical journey core.
-- Additive migration: the V2 trade, finance, Academy and monetization engines remain intact.

alter table public.profiles add column if not exists public_score_opt_in boolean not null default false;
alter table public.profiles add column if not exists financial_archetype text;
alter table public.profiles add column if not exists daily_goal_minutes integer not null default 5 check (daily_goal_minutes between 3 and 30);

create table if not exists public.konsens_score_snapshots (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  total_score integer not null check (total_score between 0 and 100),
  knowledge_score integer not null check (knowledge_score between 0 and 100),
  calibration_score integer not null check (calibration_score between 0 and 100),
  risk_score integer not null check (risk_score between 0 and 100),
  discipline_score integer not null check (discipline_score between 0 and 100),
  consistency_score integer not null check (consistency_score between 0 and 100),
  performance_score integer not null check (performance_score between 0 and 100),
  archetype text not null,
  explanation jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now()
);
create index if not exists konsens_score_user_time_idx on public.konsens_score_snapshots(user_id,recorded_at desc);
alter table public.konsens_score_snapshots enable row level security;
drop policy if exists konsens_score_own on public.konsens_score_snapshots;
create policy konsens_score_own on public.konsens_score_snapshots for select to authenticated using (auth.uid()=user_id);
grant select on public.konsens_score_snapshots to authenticated;

create table if not exists public.decision_journal (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  trade_order_id uuid unique references public.trade_orders(id) on delete set null,
  decision_type text not null check (decision_type in ('prediction','investment','replay','what_if')),
  asset_id uuid references public.assets(id) on delete set null,
  market_id uuid references public.markets(id) on delete set null,
  outcome text,
  reason_code text not null default 'intuition' check (reason_code in ('news','analysis','lesson','consensus','intuition','coach','other')),
  confidence smallint not null default 50 check (confidence between 1 and 99),
  thesis text,
  credits numeric(18,4),
  entry_price numeric(18,8),
  result_delta numeric(18,4),
  result_label text,
  lesson text,
  decision_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create index if not exists decision_journal_user_time_idx on public.decision_journal(user_id,decision_at desc);
alter table public.decision_journal enable row level security;
drop policy if exists decision_journal_own on public.decision_journal;
create policy decision_journal_own on public.decision_journal for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
grant select,insert,update,delete on public.decision_journal to authenticated;

create table if not exists public.daily_journeys (
  journey_day date primary key,
  title text not null,
  subtitle text not null,
  steps jsonb not null,
  generated_at timestamptz not null default now(),
  published boolean not null default true
);
alter table public.daily_journeys enable row level security;
drop policy if exists daily_journeys_read on public.daily_journeys;
create policy daily_journeys_read on public.daily_journeys for select to authenticated using(published=true);
grant select on public.daily_journeys to authenticated;

create table if not exists public.daily_journey_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  journey_day date not null references public.daily_journeys(journey_day) on delete cascade,
  completed_steps text[] not null default '{}',
  answers jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key(user_id,journey_day)
);
alter table public.daily_journey_progress enable row level security;
drop policy if exists daily_progress_own on public.daily_journey_progress;
create policy daily_progress_own on public.daily_journey_progress for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
grant select,insert,update on public.daily_journey_progress to authenticated;

create table if not exists public.coach_insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  insight_type text not null,
  priority smallint not null default 50 check(priority between 1 and 100),
  title text not null,
  body text not null,
  action_label text,
  action_route text,
  evidence jsonb not null default '{}'::jsonb,
  premium_only boolean not null default false,
  created_at timestamptz not null default now(),
  expires_at timestamptz,
  dismissed_at timestamptz
);
create index if not exists coach_insights_user_idx on public.coach_insights(user_id,created_at desc);
alter table public.coach_insights enable row level security;
drop policy if exists coach_insights_own on public.coach_insights;
create policy coach_insights_own on public.coach_insights for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
grant select,update on public.coach_insights to authenticated;

create table if not exists public.replay_scenarios (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  title text not null,
  era text not null,
  setup text not null,
  known_at_time jsonb not null,
  choices jsonb not null,
  reveal_text text not null,
  lesson text not null,
  source_urls text[] not null default '{}',
  difficulty text not null default 'beginner',
  active boolean not null default true,
  position integer not null default 0
);
alter table public.replay_scenarios enable row level security;
drop policy if exists replay_scenarios_read on public.replay_scenarios;
create policy replay_scenarios_read on public.replay_scenarios for select to authenticated using(active=true);
grant select on public.replay_scenarios to authenticated;

create table if not exists public.replay_attempts (
  id uuid primary key default gen_random_uuid(),
  scenario_id uuid not null references public.replay_scenarios(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  choice_key text not null,
  confidence smallint not null default 50 check(confidence between 1 and 99),
  score integer not null default 0 check(score between 0 and 100),
  reflection text,
  attempted_at timestamptz not null default now()
);
create index if not exists replay_attempts_user_idx on public.replay_attempts(user_id,attempted_at desc);
alter table public.replay_attempts enable row level security;
drop policy if exists replay_attempts_own on public.replay_attempts;
create policy replay_attempts_own on public.replay_attempts for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id);
grant select,insert on public.replay_attempts to authenticated;

alter table public.leagues add column if not exists ranking_dimension text not null default 'konsens_score' check(ranking_dimension in ('konsens_score','prediction','knowledge','risk','performance'));
alter table public.leagues add column if not exists description text;
alter table public.leagues add column if not exists is_public boolean not null default false;

create table if not exists public.saved_scenarios (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  scenario_type text not null check(scenario_type in ('asset_what_if','allocation_what_if')),
  title text not null,
  inputs jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.saved_scenarios enable row level security;
drop policy if exists saved_scenarios_own on public.saved_scenarios;
create policy saved_scenarios_own on public.saved_scenarios for all to authenticated using(auth.uid()=user_id) with check(auth.uid()=user_id and public.konsens_is_premium(auth.uid()));
grant select,insert,delete on public.saved_scenarios to authenticated;

insert into public.replay_scenarios(slug,title,era,setup,known_at_time,choices,reveal_text,lesson,source_urls,difficulty,position) values
('covid-2020','11 mars 2020 · Le monde bascule','Mars 2020','L’OMS vient de caractériser la COVID-19 comme une pandémie. Les marchés ont déjà fortement chuté et l’incertitude est extrême.','["Une pandémie mondiale est désormais officiellement reconnue","La volatilité est très élevée","Personne ne connaît encore la durée des restrictions"]','[{"key":"sell_all","label":"Tout vendre","score":35},{"key":"hold_diversified","label":"Conserver un portefeuille diversifié","score":90},{"key":"all_in","label":"Tout renforcer sur un seul actif risqué","score":25}]','La crise a encore produit de fortes secousses, puis de nombreux marchés ont rebondi. Le point pédagogique n’est pas de deviner le point bas, mais de distinguer panique, horizon et diversification.','Une décision robuste tient compte de l’horizon, de la liquidité disponible et de la diversification plutôt que de chercher à prédire parfaitement le lendemain.',array['https://www.who.int/director-general/speeches/detail/who-director-general-s-opening-remarks-at-the-media-briefing-on-covid-19---11-march-2020'],'beginner',1),
('fed-2022','15 juin 2022 · Choc de taux','Juin 2022','La Réserve fédérale relève fortement son taux directeur pour combattre une inflation élevée. Les actifs sensibles aux taux sont sous pression.','["Inflation élevée","Hausse de 75 points de base annoncée par la Fed","Les taux plus élevés modifient la valeur actualisée des flux futurs"]','[{"key":"ignore_rates","label":"Ignorer les taux et ne regarder que les cours passés","score":25},{"key":"review_duration","label":"Réévaluer duration, valorisations et diversification","score":95},{"key":"leverage_up","label":"Augmenter fortement le levier pour se refaire","score":10}]','La hausse des taux a profondément changé les conditions financières. Les entreprises de croissance, les obligations et le coût du crédit ont réagi de façons différentes.','Les taux d’intérêt sont un prix central de la finance : ils influencent obligations, valorisations, immobilier et coût du capital.',array['https://www.federalreserve.gov/newsevents/pressreleases/monetary20220615a.htm'],'intermediate',2),
('svb-2023','Mars 2023 · Stress bancaire','Mars 2023','Une grande banque américaine spécialisée dans la technologie vient d’être fermée par le régulateur. Les marchés s’interrogent sur la contagion.','["Une banque importante vient d’être fermée","Le risque de liquidité bancaire revient au premier plan","L’information disponible ne permet pas encore de mesurer toute la contagion"]','[{"key":"assume_total_collapse","label":"Parier sur l’effondrement complet du système","score":20},{"key":"map_exposure","label":"Cartographier les expositions et attendre des faits supplémentaires","score":95},{"key":"ignore_event","label":"Ignorer totalement le risque bancaire","score":30}]','Les autorités ont pris des mesures de stabilisation et l’événement a rappelé que risque de taux, liquidité et concentration peuvent interagir rapidement.','Dans une crise, séparer faits connus, scénarios possibles et certitudes imaginées améliore fortement la qualité de décision.',array['https://www.fdic.gov/news/press-releases/2023/pr23016.html'],'intermediate',3)
on conflict(slug) do update set title=excluded.title,setup=excluded.setup,known_at_time=excluded.known_at_time,choices=excluded.choices,reveal_text=excluded.reveal_text,lesson=excluded.lesson,source_urls=excluded.source_urls,difficulty=excluded.difficulty,position=excluded.position,active=true;

create or replace function public.ensure_daily_journey(p_day date default current_date)
returns public.daily_journeys language plpgsql security definer set search_path=public as $$
declare j public.daily_journeys;m record;a record;l record;built_steps jsonb;
begin
  select * into j from public.daily_journeys where journey_day=p_day;if found then return j;end if;
  select id,question,category,yes_probability,source_summary,closes_at into m from public.markets where status='open' order by md5(id::text||p_day::text) limit 1;
  select id,symbol,name,description,sector into a from public.assets where is_active=true and external_ref like 'market:%' order by md5(id::text||p_day::text) limit 1;
  select id,title,summary,concept,duration_minutes into l from public.learning_modules where is_active=true order by md5(id::text||p_day::text) limit 1;
  built_steps:=jsonb_build_array(
    jsonb_build_object('key','understand','type','understand','eyebrow','COMPRENDRE','title',coalesce(m.category,'Actualité')||' · Ce que le marché essaie de dire','body',coalesce(m.source_summary,m.question,'Observe les faits avant de décider.'),'minutes',1,'market_id',m.id),
    jsonb_build_object('key','predict','type','predict','eyebrow','PRÉDIRE','title',coalesce(m.question,'Quelle est ta probabilité ?'),'body','Donne ton scénario et surtout ton niveau de confiance.','minutes',1,'market_id',m.id,'community_probability',round(coalesce(m.yes_probability,.5)*100)),
    jsonb_build_object('key','decide','type','decide','eyebrow','DÉCIDER','title','Que ferais-tu avec 100 Koins sur '||coalesce(a.symbol,'cet actif')||' ?','body',coalesce(a.description,'Observe le risque avant de choisir.'),'minutes',1,'asset_id',a.id,'symbol',a.symbol,'asset_name',a.name),
    jsonb_build_object('key','learn','type','learn','eyebrow','APPRENDRE','title',coalesce(l.title,'Leçon du jour'),'body',coalesce(l.summary,l.concept,'Une notion pour renforcer ta décision.'),'minutes',greatest(1,least(coalesce(l.duration_minutes,5),5)),'module_id',l.id)
  );
  insert into public.daily_journeys(journey_day,title,subtitle,steps) values(p_day,'Ton Konsens du jour','4 étapes · environ 5 minutes',built_steps) returning * into j;return j;
end$$;
grant execute on function public.ensure_daily_journey(date) to authenticated;

create or replace function public.get_my_daily_journey()
returns table(journey_day date,title text,subtitle text,steps jsonb,completed_steps text[],answers jsonb,completed_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare j public.daily_journeys;
begin
  if auth.uid() is null then raise exception 'authentication_required';end if;
  j:=public.ensure_daily_journey(current_date);
  insert into public.daily_journey_progress(user_id,journey_day) values(auth.uid(),current_date) on conflict do nothing;
  return query select j.journey_day,j.title,j.subtitle,j.steps,p.completed_steps,p.answers,p.completed_at from public.daily_journey_progress p where p.user_id=auth.uid() and p.journey_day=current_date;
end$$;
grant execute on function public.get_my_daily_journey() to authenticated;

create or replace function public.complete_daily_step(p_step_key text,p_answer jsonb default '{}'::jsonb)
returns table(completed_steps text[],completed_at timestamptz,xp integer)
language plpgsql security definer set search_path=public as $$
declare arr text[];done_at timestamptz;award integer:=0;already boolean;prev date;
begin
  if auth.uid() is null then raise exception 'authentication_required';end if;
  perform public.ensure_daily_journey(current_date);
  insert into public.daily_journey_progress(user_id,journey_day) values(auth.uid(),current_date) on conflict do nothing;
  select p_step_key=any(p.completed_steps) into already from public.daily_journey_progress p where p.user_id=auth.uid() and p.journey_day=current_date;
  update public.daily_journey_progress p set completed_steps=case when p_step_key=any(p.completed_steps) then p.completed_steps else array_append(p.completed_steps,p_step_key) end,answers=coalesce(p.answers,'{}'::jsonb)||jsonb_build_object(p_step_key,coalesce(p_answer,'{}'::jsonb)) where p.user_id=auth.uid() and p.journey_day=current_date returning p.completed_steps into arr;
  if not already then award:=5;update public.profiles set xp=xp+award,updated_at=now() where id=auth.uid();end if;
  if cardinality(arr)>=4 then
    update public.daily_journey_progress p set completed_at=coalesce(p.completed_at,now()) where p.user_id=auth.uid() and p.journey_day=current_date returning p.completed_at into done_at;
    select last_active_on into prev from public.profiles where id=auth.uid();
    update public.profiles set streak_days=case when prev=current_date then streak_days when prev=current_date-1 then streak_days+1 else 1 end,last_active_on=current_date,updated_at=now() where id=auth.uid();
  end if;
  return query select arr,done_at,award;
end$$;
grant execute on function public.complete_daily_step(text,jsonb) to authenticated;

create or replace function public.record_decision_journal(p_trade_order_id uuid,p_reason_code text,p_confidence integer,p_thesis text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare o record;jid uuid;dtype text;
begin
  select * into o from public.trade_orders where id=p_trade_order_id and user_id=auth.uid();if not found then raise exception 'order_not_found';end if;
  dtype:=case when o.market_id is not null then 'prediction' else 'investment' end;
  insert into public.decision_journal(user_id,trade_order_id,decision_type,asset_id,market_id,outcome,reason_code,confidence,thesis,credits,entry_price,decision_at)
  values(auth.uid(),o.id,dtype,o.asset_id,o.market_id,o.outcome,case when p_reason_code in('news','analysis','lesson','consensus','intuition','coach','other') then p_reason_code else 'other' end,greatest(1,least(p_confidence,99)),nullif(trim(p_thesis),''),o.credits,o.execution_price,coalesce(o.executed_at,o.created_at))
  on conflict(trade_order_id) do update set reason_code=excluded.reason_code,confidence=excluded.confidence,thesis=excluded.thesis returning id into jid;return jid;
end$$;
grant execute on function public.record_decision_journal(uuid,text,integer,text) to authenticated;

create or replace function public.get_market_consensus_comparison(p_market_id uuid)
returns table(community_probability numeric,ai_initial_probability numeric,my_probability numeric,my_confidence integer,my_outcome text)
language sql stable security definer set search_path=public as $$
  select m.yes_probability,case when m.ai_confidence is null then null else m.yes_probability end,case when j.id is null then null when j.outcome='yes' then j.confidence::numeric/100 else 1-j.confidence::numeric/100 end,j.confidence,j.outcome
  from public.markets m left join lateral(select * from public.decision_journal d where d.user_id=auth.uid() and d.market_id=m.id and d.decision_type='prediction' order by d.decision_at desc limit 1)j on true where m.id=p_market_id;
$$;
grant execute on function public.get_market_consensus_comparison(uuid) to authenticated;

create or replace function public.get_my_konsens_score(p_persist boolean default true)
returns table(total_score integer,knowledge_score integer,calibration_score integer,risk_score integer,discipline_score integer,consistency_score integer,performance_score integer,archetype text,explanation jsonb)
language plpgsql security definer set search_path=public as $$
declare k int:=0;c int:=50;r int:=70;d int:=60;s int:=0;p int:=50;total int;arch text;expl jsonb;module_count int;completed_count int;avg_learning numeric;journal_count int;avg_conf numeric;position_count int;max_share numeric;streak int;wealth_total numeric;perf numeric;
begin
  if auth.uid() is null then raise exception 'authentication_required';end if;
  select count(*) into module_count from public.learning_modules where is_active=true;
  select count(*),coalesce(avg(score),0) into completed_count,avg_learning from public.learning_progress where user_id=auth.uid() and completed_at is not null;
  if module_count>0 then k:=least(100,round((completed_count::numeric/module_count)*60+(avg_learning/100)*40));end if;
  select count(*),coalesce(avg(confidence),50) into journal_count,avg_conf from public.decision_journal where user_id=auth.uid();
  c:=case when journal_count=0 then 50 else greatest(25,least(95,round(80-abs(avg_conf-65)*0.7))) end;
  select count(*) into position_count from public.positions where user_id=auth.uid() and quantity>0;
  select case when sum(v)<=0 then 0 else max(v)/sum(v) end into max_share from(select coalesce(quantity*average_price,0)v from public.positions where user_id=auth.uid() and quantity>0)x;
  r:=case when position_count=0 then 70 when position_count=1 then 45 when coalesce(max_share,1)>.65 then 50 when coalesce(max_share,1)>.40 then 70 else 88 end;
  d:=least(100,45+least(journal_count,10)*3+least(completed_count,5)*5);
  select streak_days into streak from public.profiles where id=auth.uid();s:=least(100,coalesce(streak,0)*10);
  select total_value into wealth_total from public.get_my_wealth_snapshot() limit 1;perf:=coalesce((wealth_total-1000)/10,0);p:=greatest(20,least(95,round(50+perf)));
  total:=round(k*.22+c*.18+r*.20+d*.15+s*.10+p*.15);
  arch:=case when k>=75 and r>=70 then 'Analyste discipliné' when c>=75 then 'Prévisionniste calibré' when r>=80 then 'Gestionnaire prudent' when p>=75 and r<60 then 'Explorateur offensif' when k<45 then 'Apprenant en progression' else 'Décideur équilibré' end;
  expl:=jsonb_build_object('headline','Ton score récompense la qualité de décision, pas seulement les gains.','journal_decisions',journal_count,'modules_completed',completed_count,'positions',position_count,'max_position_share',coalesce(max_share,0),'wealth',coalesce(wealth_total,0));
  update public.profiles set financial_archetype=arch where id=auth.uid();
  if p_persist then insert into public.konsens_score_snapshots(user_id,total_score,knowledge_score,calibration_score,risk_score,discipline_score,consistency_score,performance_score,archetype,explanation) values(auth.uid(),total,k,c,r,d,s,p,arch,expl);end if;
  return query select total,k,c,r,d,s,p,arch,expl;
end$$;
grant execute on function public.get_my_konsens_score(boolean) to authenticated;

create or replace function public.refresh_my_coach_insights()
returns table(id uuid,insight_type text,priority smallint,title text,body text,action_label text,action_route text,evidence jsonb,premium_only boolean,created_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare score record;pos_count int;journal_count int;comp_count int;premium boolean;
begin
  if auth.uid() is null then raise exception 'authentication_required';end if;
  select * into score from public.get_my_konsens_score(false) limit 1;
  select count(*) into pos_count from public.positions where user_id=auth.uid() and quantity>0;
  select count(*) into journal_count from public.decision_journal where user_id=auth.uid();
  select count(*) into comp_count from public.learning_progress where user_id=auth.uid() and completed_at is not null;
  premium:=public.konsens_is_premium(auth.uid());
  delete from public.coach_insights where user_id=auth.uid() and dismissed_at is null and created_at<now()-interval '1 day';
  if not exists(select 1 from public.coach_insights where user_id=auth.uid() and insight_type='score_focus' and dismissed_at is null and created_at>now()-interval '12 hours') then
    insert into public.coach_insights(user_id,insight_type,priority,title,body,action_label,action_route,evidence)
    values(auth.uid(),'score_focus',90,'Ton prochain levier : '||case when score.knowledge_score<=least(score.risk_score,score.calibration_score) then 'connaissance' when score.risk_score<=score.calibration_score then 'gestion du risque' else 'calibration' end,
      case when score.knowledge_score<=least(score.risk_score,score.calibration_score) then 'Un module Academy aujourd’hui améliorera davantage ton profil que chercher un gain rapide.' when score.risk_score<=score.calibration_score then 'Ton portefeuille gagnerait à être observé sous l’angle concentration et perte potentielle.' else 'Avant ta prochaine prédiction, note ton niveau de confiance : Konsens pourra comparer conviction et résultat.' end,
      case when score.knowledge_score<=least(score.risk_score,score.calibration_score) then 'Ouvrir Academy' when score.risk_score<=score.calibration_score then 'Voir mes positions' else 'Faire une prédiction' end,
      case when score.knowledge_score<=least(score.risk_score,score.calibration_score) then 'learn' when score.risk_score<=score.calibration_score then 'invest' else 'play' end,
      jsonb_build_object('score',score.total_score,'knowledge',score.knowledge_score,'risk',score.risk_score,'calibration',score.calibration_score));
  end if;
  if journal_count>=3 and premium and not exists(select 1 from public.coach_insights where user_id=auth.uid() and insight_type='decision_pattern' and dismissed_at is null and created_at>now()-interval '12 hours') then
    insert into public.coach_insights(user_id,insight_type,priority,title,body,action_label,action_route,evidence,premium_only)
    select auth.uid(),'decision_pattern',80,'Ton comportement commence à devenir lisible','Tu as documenté '||journal_count||' décisions. Le Coach Premium peut maintenant comparer tes motifs, ta confiance et ton exposition pour faire émerger des habitudes récurrentes.','Voir mon journal','profile',jsonb_build_object('decisions',journal_count,'positions',pos_count,'completed_modules',comp_count),true;
  end if;
  return query select c.id,c.insight_type,c.priority,c.title,c.body,c.action_label,c.action_route,c.evidence,c.premium_only,c.created_at from public.coach_insights c where c.user_id=auth.uid() and c.dismissed_at is null and(not c.premium_only or premium) order by c.priority desc,c.created_at desc limit 8;
end$$;
grant execute on function public.refresh_my_coach_insights() to authenticated;

create or replace function public.submit_replay_attempt(p_scenario_id uuid,p_choice_key text,p_confidence integer,p_reflection text default null)
returns table(score integer,reveal_text text,lesson text)
language plpgsql security definer set search_path=public as $$
declare sc public.replay_scenarios;choice jsonb;points int:=0;
begin
  if auth.uid() is null then raise exception 'authentication_required';end if;
  select * into sc from public.replay_scenarios where id=p_scenario_id and active=true;if not found then raise exception 'scenario_not_found';end if;
  select elem into choice from jsonb_array_elements(sc.choices)elem where elem->>'key'=p_choice_key limit 1;if choice is null then raise exception 'invalid_choice';end if;
  points:=coalesce((choice->>'score')::int,0);
  insert into public.replay_attempts(scenario_id,user_id,choice_key,confidence,score,reflection) values(sc.id,auth.uid(),p_choice_key,greatest(1,least(p_confidence,99)),points,nullif(trim(p_reflection),''));
  update public.profiles set xp=xp+greatest(2,round(points/20.0)::int) where id=auth.uid();
  return query select points,sc.reveal_text,sc.lesson;
end$$;
grant execute on function public.submit_replay_attempt(uuid,text,integer,text) to authenticated;

create or replace function public.simulate_asset_what_if(p_asset_id uuid,p_koins numeric default 100)
returns table(asset_id uuid,symbol text,asset_name text,observed_from timestamptz,observed_to timestamptz,start_price numeric,current_price numeric,invested_koins numeric,current_value_koins numeric,gain_loss_koins numeric,gain_loss_percent numeric,history_limited boolean)
language sql stable security definer set search_path=public as $$
  with prices as(select ph.asset_id,min(ph.observed_at)first_at,max(ph.observed_at)last_at,(array_agg(ph.price order by ph.observed_at asc))[1]first_price,(array_agg(ph.price order by ph.observed_at desc))[1]last_price,count(*)n from public.price_history ph where ph.asset_id=p_asset_id group by ph.asset_id)
  select a.id,a.symbol,a.name,p.first_at,p.last_at,p.first_price,p.last_price,p_koins,case when p.first_price>0 then p_koins*(p.last_price/p.first_price) else p_koins end,case when p.first_price>0 then p_koins*(p.last_price/p.first_price)-p_koins else 0 end,case when p.first_price>0 then(p.last_price/p.first_price-1)*100 else 0 end,(p.n<20 or p.first_at>now()-interval '90 days') from public.assets a join prices p on p.asset_id=a.id where a.id=p_asset_id;
$$;
grant execute on function public.simulate_asset_what_if(uuid,numeric) to authenticated;

create or replace function public.get_league_leaderboard(p_league_id uuid)
returns table(rank bigint,user_id uuid,username text,archetype text,konsens_score integer,knowledge_score integer,risk_score integer,performance_score integer)
language sql stable security definer set search_path=public as $$
  with members as(select lm.user_id from public.league_members lm where lm.league_id=p_league_id and exists(select 1 from public.league_members me where me.league_id=p_league_id and me.user_id=auth.uid())),scored as(select m.user_id,p.username,p.financial_archetype,coalesce(s.total_score,50)total_score,coalesce(s.knowledge_score,0)knowledge_score,coalesce(s.risk_score,70)risk_score,coalesce(s.performance_score,50)performance_score from members m join public.profiles p on p.id=m.user_id left join lateral(select * from public.konsens_score_snapshots ks where ks.user_id=m.user_id order by recorded_at desc limit 1)s on true)
  select row_number() over(order by total_score desc,knowledge_score desc),user_id,username,coalesce(financial_archetype,'Décideur équilibré'),total_score,knowledge_score,risk_score,performance_score from scored;
$$;
grant execute on function public.get_league_leaderboard(uuid) to authenticated;

insert into public.leagues(name,join_code,owner_id,season_id,ranking_dimension,description,is_public)
select 'Konsens France','FRANCE',p.id,s.id,'konsens_score','La ligue générale de la bêta : le classement récompense la qualité de décision, pas uniquement le patrimoine.',true
from (select id from public.profiles where role='admin' order by created_at limit 1)p cross join (select id from public.seasons where is_active=true order by starts_at desc limit 1)s
on conflict(join_code) do update set description=excluded.description,ranking_dimension='konsens_score',is_public=true;
insert into public.league_members(league_id,user_id)
select l.id,p.id from public.leagues l cross join public.profiles p where l.join_code='FRANCE' and p.role='admin' on conflict do nothing;
