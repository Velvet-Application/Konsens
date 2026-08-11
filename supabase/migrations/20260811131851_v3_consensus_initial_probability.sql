create or replace function public.get_market_consensus_comparison(p_market_id uuid)
returns table(community_probability numeric,ai_initial_probability numeric,my_probability numeric,my_confidence integer,my_outcome text)
language sql stable security definer set search_path=public as $$
  select m.yes_probability,
    (select h.yes_probability from public.market_probability_history h where h.market_id=m.id order by h.observed_at asc limit 1),
    case when j.id is null then null when j.outcome='yes' then j.confidence::numeric/100 else 1-j.confidence::numeric/100 end,
    j.confidence,j.outcome
  from public.markets m
  left join lateral(select * from public.decision_journal d where d.user_id=auth.uid() and d.market_id=m.id and d.decision_type='prediction' order by d.decision_at desc limit 1)j on true
  where m.id=p_market_id;
$$;
grant execute on function public.get_market_consensus_comparison(uuid) to authenticated;
