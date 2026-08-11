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
