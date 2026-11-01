create table discount_codes (
  code text primary key,
  percent numeric not null check (percent > 0 and percent <= 100)
);

insert into discount_codes (code, percent) values ('LAUNCH10', 10);
