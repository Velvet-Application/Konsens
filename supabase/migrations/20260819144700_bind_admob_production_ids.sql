-- Bind rewarded-video intents and credited rewards to the known Konsens AdMob units.
-- Debug builds may create intents only for Google's official rewarded test unit.
-- Production credits must always come from the owned Konsens rewarded unit.

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname='admob_reward_intents_known_ad_unit_ck'
      and conrelid='public.admob_reward_intents'::regclass
  ) then
    alter table public.admob_reward_intents
      add constraint admob_reward_intents_known_ad_unit_ck
      check (
        ad_unit in (
          'ca-app-pub-3940256099942544/1712485313',
          'ca-app-pub-7926506553495295/6184760199'
        )
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname='game_daily_rewards_owned_ad_unit_ck'
      and conrelid='public.game_daily_rewards'::regclass
  ) then
    alter table public.game_daily_rewards
      add constraint game_daily_rewards_owned_ad_unit_ck
      check (
        reward_ad_unit is null
        or reward_ad_unit='ca-app-pub-7926506553495295/6184760199'
      );
  end if;
end $$;

comment on constraint admob_reward_intents_known_ad_unit_ck on public.admob_reward_intents is
  'Only the official Google iOS rewarded test unit or the owned Konsens production rewarded unit can open a reward intent.';

comment on constraint game_daily_rewards_owned_ad_unit_ck on public.game_daily_rewards is
  'Any AdMob-backed daily credit must originate from the owned Konsens production rewarded unit.';
