-- Final reward-credit lockdown for AdMob SSV.
-- This migration MUST be applied immediately after 20260819144500_rewarded_video_admob.sql.
-- No authenticated client may retain a wallet-crediting rewarded-ad RPC.

-- Legacy pre-SSV client-authoritative reward functions.
drop function if exists public.claim_daily_reward(bigint);
drop function if exists public.claim_daily_reward_video(text,text,uuid);

-- Reassert that only service_role may execute the SSV finalizer.
revoke all on function public.finalize_daily_reward_video_ssv(
  uuid,uuid,text,text,bigint,text,text,numeric
) from public,anon,authenticated;

grant execute on function public.finalize_daily_reward_video_ssv(
  uuid,uuid,text,text,bigint,text,text,numeric
) to service_role;

-- Authenticated users may only create/read their own pending reward intent.
revoke all on function public.begin_daily_reward_video(text) from public,anon;
grant execute on function public.begin_daily_reward_video(text) to authenticated;

revoke all on function public.get_my_reward_video_intent(uuid) from public,anon;
grant execute on function public.get_my_reward_video_intent(uuid) to authenticated;

comment on function public.finalize_daily_reward_video_ssv(uuid,uuid,text,text,bigint,text,text,numeric) is
  'LOCKED: service-role-only economic mutation after cryptographic AdMob SSV verification. No client-side rewarded callback may invoke this function.';
