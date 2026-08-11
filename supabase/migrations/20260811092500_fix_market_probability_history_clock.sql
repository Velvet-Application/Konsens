-- Use wall-clock timestamps for successive market movements inside the same
-- transaction. now() is transaction-stable and can collide with the composite
-- primary key (market_id, observed_at) during rapid buy/sell sequences.

alter table public.market_probability_history
  alter column observed_at set default clock_timestamp();
