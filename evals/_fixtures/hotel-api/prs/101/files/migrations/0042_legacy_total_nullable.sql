-- New quotes no longer store a precomputed total; it is derived from accommodation blocks.
alter table quotes alter column legacy_total drop not null;
