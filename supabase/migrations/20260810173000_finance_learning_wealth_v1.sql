-- Finance-first Konsens model: 1,000 Koins, wealth snapshot, premium naming and simulation assets.
alter table public.profiles add column if not exists journey_mode text not null default 'balanced';
alter table public.profiles add column if not exists risk_acknowledged_at timestamptz;
alter table public.profiles drop constraint if exists profiles_journey_mode_check;
alter table public.profiles add constraint profiles_journey_mode_check check (journey_mode in ('balanced','play','learn'));

update public.profiles set subscription_tier='premium' where subscription_tier='plus';
alter table public.profiles drop constraint if exists profiles_subscription_tier_check;
alter table public.profiles add constraint profiles_subscription_tier_check check (subscription_tier in ('free','premium'));

alter table public.wallets alter column cash set default 1000;
alter table public.wallets alter column total_allocated set default 0;

alter table public.ledger_entries drop constraint if exists ledger_entries_entry_type_check;
alter table public.ledger_entries add constraint ledger_entries_entry_type_check check (entry_type in ('allocation','initial_koin_grant','trade_debit','trade_credit','settlement','adjustment'));

create or replace function private.create_profile_for_user()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_username text; v_role text;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('konsens_first_admin'));
  v_username := 'joueur_' || substr(replace(new.id::text,'-',''),1,8);
  v_role := case when exists(select 1 from public.profiles where role='admin') then 'user' else 'admin' end;
  insert into public.profiles(id,username,display_name,avatar_seed,email,role)
  values(new.id,v_username,v_username,upper(substr(v_username,1,1)),new.email,v_role);
  insert into public.wallets(user_id,cash,total_allocated) values(new.id,1000,0);
  insert into public.ledger_entries(user_id,entry_type,amount,balance_after,metadata)
  values(new.id,'initial_koin_grant',1000,1000,jsonb_build_object('currency','KOIN','reason','welcome_grant'));
  return new;
end $$;

with virgin as (
  select w.user_id from public.wallets w
  where w.cash=0 and w.total_allocated=0
    and not exists(select 1 from public.positions p where p.user_id=w.user_id)
    and not exists(select 1 from public.ledger_entries l where l.user_id=w.user_id and l.entry_type in ('trade_debit','trade_credit','settlement'))
)
update public.wallets w set cash=1000,updated_at=now() from virgin v where w.user_id=v.user_id;

insert into public.ledger_entries(user_id,entry_type,amount,balance_after,metadata)
select w.user_id,'initial_koin_grant',1000,1000,jsonb_build_object('currency','KOIN','reason','beta_alignment')
from public.wallets w
where w.cash=1000 and not exists(select 1 from public.ledger_entries l where l.user_id=w.user_id and l.entry_type='initial_koin_grant');

create or replace function public.get_my_wealth_snapshot()
returns table(cash_value numeric,investments_value numeric,bets_value numeric,total_value numeric)
language sql stable security definer set search_path='' as $$
with me as (select auth.uid() uid),
cash as (select coalesce(w.cash,0)::numeric cash_value from public.wallets w,me where w.user_id=me.uid),
asset_positions as (
  select coalesce(sum(p.quantity * coalesce(latest.price,p.average_price)),0)::numeric investments_value
  from public.positions p,me
  left join lateral (select ph.price from public.price_history ph where ph.asset_id=p.asset_id order by ph.observed_at desc limit 1) latest on true
  where p.user_id=me.uid and p.asset_id is not null
),
bet_positions as (
  select coalesce(sum(p.quantity * case
    when m.resolved_outcome is not null then case when (p.side::text='yes' and m.resolved_outcome) or (p.side::text='no' and not m.resolved_outcome) then 1 else 0 end
    when p.side::text='yes' then m.yes_probability else 1-m.yes_probability end),0)::numeric bets_value
  from public.positions p join public.markets m on m.id=p.market_id,me
  where p.user_id=me.uid and p.market_id is not null
)
select c.cash_value,a.investments_value,b.bets_value,(c.cash_value+a.investments_value+b.bets_value)::numeric
from cash c cross join asset_positions a cross join bet_positions b;
$$;
revoke all on function public.get_my_wealth_snapshot() from public;
grant execute on function public.get_my_wealth_snapshot() to authenticated;

insert into public.assets(symbol,name,kind,currency,external_ref,is_active) values
('KMONDE','Konsens Monde','index','EUR','sim:kmonde',true),
('KTECH','Konsens Tech 100','index','EUR','sim:ktech',true),
('KDEF','Konsens Défensif','etf','EUR','sim:kdef',true)
on conflict(symbol) do update set name=excluded.name,kind=excluded.kind,external_ref=excluded.external_ref,is_active=true;

insert into public.price_history(asset_id,observed_at,price,source)
select a.id,now(),v.price,'simulation_seed'
from (values ('KMONDE'::text,100::numeric),('KTECH'::text,125::numeric),('KDEF'::text,80::numeric)) v(symbol,price)
join public.assets a on a.symbol=v.symbol
where not exists(select 1 from public.price_history ph where ph.asset_id=a.id and ph.source='simulation_seed');
