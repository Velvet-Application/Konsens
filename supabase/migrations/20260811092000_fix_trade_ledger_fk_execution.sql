-- Fix order execution: the BEFORE INSERT trade trigger writes the ledger entry
-- using NEW.id before the parent trade_orders row is visible to an immediate FK.
-- Deferring this FK until transaction end lets the atomic trade complete while
-- preserving referential integrity.

alter table public.ledger_entries
  alter constraint ledger_entries_order_id_fkey
  deferrable initially deferred;
