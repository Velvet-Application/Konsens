create unique index if not exists ad_events_impression_once_idx on public.ad_events(session_id,creative_id,(coalesce(slot_key,''))) where event_type='impression';

create or replace function public.track_ad_event(
  p_campaign_id uuid,
  p_creative_id uuid,
  p_event_type text,
  p_placement text,
  p_session_id text,
  p_slot_key text default null,
  p_resource_id text default null,
  p_metadata jsonb default '{}'::jsonb
) returns bigint
language plpgsql volatile security definer set search_path = '' as $$
declare v_id bigint;
begin
  if p_event_type not in ('impression','click','conversion') then raise exception 'invalid_event_type'; end if;
  if p_placement not in ('feed_native','challenge_sponsor','post_prediction') then raise exception 'invalid_placement'; end if;
  if char_length(coalesce(p_session_id,'')) not between 8 and 100 then raise exception 'invalid_session'; end if;
  if not exists(select 1 from public.ad_creatives where id=p_creative_id and campaign_id=p_campaign_id and is_active) then raise exception 'invalid_creative'; end if;
  insert into public.ad_events(campaign_id,creative_id,user_id,session_id,event_type,placement,slot_key,resource_id,metadata)
  values(p_campaign_id,p_creative_id,(select auth.uid()),p_session_id,p_event_type,p_placement,p_slot_key,p_resource_id,coalesce(p_metadata,'{}'::jsonb))
  on conflict do nothing
  returning id into v_id;
  return coalesce(v_id,0);
end $$;

revoke all on function public.get_challenge_signal(uuid) from anon,authenticated;

create or replace function public.get_sdk_challenge_signal(
  p_api_key text,
  p_origin text,
  p_challenge_id uuid
) returns table(
  challenge_id uuid,
  question text,
  yes_count bigint,
  no_count bigint,
  total_count bigint,
  yes_ratio numeric,
  client_plan text,
  remaining_events bigint
)
language plpgsql volatile security definer set search_path = '' as $$
declare v_client public.sdk_clients%rowtype; v_used bigint;
begin
  select * into v_client from public.sdk_clients
  where api_key_hash=extensions.encode(extensions.digest(p_api_key,'sha256'),'hex') and status='active';
  if v_client.id is null then raise exception 'invalid_api_key'; end if;
  if not ('*'=any(v_client.allowed_origins) or p_origin=any(v_client.allowed_origins)) then raise exception 'origin_not_allowed'; end if;
  select count(*) into v_used from public.sdk_events where client_id=v_client.id and occurred_at>=date_trunc('month',now());
  if v_used>=v_client.monthly_event_limit then raise exception 'monthly_limit_reached'; end if;
  if not exists(select 1 from public.daily_challenges where id=p_challenge_id) then raise exception 'challenge_not_found'; end if;
  insert into public.sdk_events(client_id,event_type,origin,metadata)
  values(v_client.id,'signal_read',p_origin,jsonb_build_object('challengeId',p_challenge_id));
  return query
  select d.id,d.question,
    count(*) filter(where a.answer is true)::bigint,
    count(*) filter(where a.answer is false)::bigint,
    count(a.user_id)::bigint,
    case when count(a.user_id)=0 then 0::numeric else round((count(*) filter(where a.answer is true))::numeric/count(a.user_id),4) end,
    v_client.plan,
    greatest(v_client.monthly_event_limit-v_used-1,0)
  from public.daily_challenges d
  left join public.challenge_answers a on a.challenge_id=d.id
  where d.id=p_challenge_id
  group by d.id,d.question;
end $$;
revoke all on function public.get_sdk_challenge_signal(text,text,uuid) from public;
grant execute on function public.get_sdk_challenge_signal(text,text,uuid) to anon,authenticated;
