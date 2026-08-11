create or replace function public.get_discoverable_leagues()
returns table(id uuid,name text,join_code text,description text,ranking_dimension text,is_member boolean,member_count bigint)
language sql stable security definer set search_path=public as $$
  select l.id,l.name,l.join_code,l.description,l.ranking_dimension,
    exists(select 1 from public.league_members me where me.league_id=l.id and me.user_id=auth.uid()),
    (select count(*) from public.league_members lm where lm.league_id=l.id)
  from public.leagues l
  where l.is_public=true or exists(select 1 from public.league_members me where me.league_id=l.id and me.user_id=auth.uid()) or l.owner_id=auth.uid()
  order by l.is_public desc,l.created_at asc;
$$;
grant execute on function public.get_discoverable_leagues() to authenticated;

create or replace function public.join_league_by_code(p_join_code text)
returns uuid language plpgsql security definer set search_path=public as $$
declare lid uuid;
begin
  if auth.uid() is null then raise exception 'authentication_required';end if;
  select id into lid from public.leagues where upper(join_code)=upper(trim(p_join_code)) limit 1;
  if lid is null then raise exception 'league_not_found';end if;
  insert into public.league_members(league_id,user_id) values(lid,auth.uid()) on conflict do nothing;
  return lid;
end$$;
grant execute on function public.join_league_by_code(text) to authenticated;

create or replace function public.create_my_league(p_name text,p_dimension text default 'konsens_score')
returns table(id uuid,join_code text)
language plpgsql security definer set search_path=public as $$
declare lid uuid;code text;sid uuid;
begin
  if auth.uid() is null then raise exception 'authentication_required';end if;
  if length(trim(p_name))<3 then raise exception 'name_too_short';end if;
  select s.id into sid from public.seasons s where s.is_active=true order by s.starts_at desc limit 1;
  code:=upper(substr(md5(gen_random_uuid()::text),1,6));
  insert into public.leagues(name,join_code,owner_id,season_id,ranking_dimension,description,is_public)
  values(trim(p_name),code,auth.uid(),sid,case when p_dimension in('konsens_score','prediction','knowledge','risk','performance') then p_dimension else 'konsens_score' end,'Ligue privée Konsens',false)
  returning leagues.id into lid;
  insert into public.league_members(league_id,user_id) values(lid,auth.uid()) on conflict do nothing;
  return query select lid,code;
end$$;
grant execute on function public.create_my_league(text,text) to authenticated;

create or replace function public.get_my_profile_card()
returns table(username text,archetype text,konsens_score integer,knowledge_score integer,calibration_score integer,risk_score integer,discipline_score integer,consistency_score integer,performance_score integer,xp integer,streak_days integer,badges jsonb)
language plpgsql security definer set search_path=public as $$
declare s record;p record;b jsonb;
begin
  select * into s from public.get_my_konsens_score(false) limit 1;
  select pr.username,pr.xp,pr.streak_days into p from public.profiles pr where pr.id=auth.uid();
  b:=jsonb_strip_nulls(jsonb_build_object(
    'scholar',case when s.knowledge_score>=70 then 'Esprit financier' else null end,
    'calibrated',case when s.calibration_score>=70 then 'Prévision calibrée' else null end,
    'risk',case when s.risk_score>=75 then 'Risque maîtrisé' else null end,
    'streak',case when coalesce(p.streak_days,0)>=7 then '7 jours réguliers' else null end
  ));
  return query select p.username,s.archetype,s.total_score,s.knowledge_score,s.calibration_score,s.risk_score,s.discipline_score,s.consistency_score,s.performance_score,p.xp,p.streak_days,
    coalesce((select jsonb_agg(jsonb_build_object('key',e.key,'label',e.value)) from jsonb_each_text(b)e),'[]'::jsonb);
end$$;
grant execute on function public.get_my_profile_card() to authenticated;
