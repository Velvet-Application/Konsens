create or replace function public.auto_seed_decision_journal()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status='executed' and (tg_op='INSERT' or old.status is distinct from new.status) then
    insert into public.decision_journal(user_id,trade_order_id,decision_type,asset_id,market_id,outcome,reason_code,confidence,credits,entry_price,decision_at)
    values(new.user_id,new.id,case when new.market_id is not null then 'prediction' else 'investment' end,new.asset_id,new.market_id,new.outcome,'intuition',50,new.credits,new.execution_price,coalesce(new.executed_at,new.created_at))
    on conflict(trade_order_id) do nothing;
  end if;
  return new;
end$$;
drop trigger if exists trg_auto_seed_decision_journal on public.trade_orders;
create trigger trg_auto_seed_decision_journal after insert or update of status on public.trade_orders for each row execute function public.auto_seed_decision_journal();

insert into public.decision_journal(user_id,trade_order_id,decision_type,asset_id,market_id,outcome,reason_code,confidence,credits,entry_price,decision_at)
select o.user_id,o.id,case when o.market_id is not null then 'prediction' else 'investment' end,o.asset_id,o.market_id,o.outcome,'intuition',50,o.credits,o.execution_price,coalesce(o.executed_at,o.created_at)
from public.trade_orders o where o.status='executed'
on conflict(trade_order_id) do nothing;
