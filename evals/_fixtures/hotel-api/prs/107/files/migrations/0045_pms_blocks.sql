-- Blocks requested from the PMS in async mode, until its webhook confirms them.
create table pms_blocks (
  block_id text primary key,
  quote_id uuid not null references quotes (id),
  status text not null
);
