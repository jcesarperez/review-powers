alter table quotes
  add column status text not null default 'open',
  add column cancelled_at timestamptz;
