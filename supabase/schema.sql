-- Reset existing objects safely (run multiple times)
do $$
begin
  if to_regclass('public.app_snapshots') is not null then
    execute 'drop policy if exists "snapshots_select_user" on app_snapshots';
    execute 'drop policy if exists "snapshots_insert_user" on app_snapshots';
    execute 'drop policy if exists "snapshots_update_user" on app_snapshots';
    execute 'drop policy if exists "snapshots_delete_user" on app_snapshots';
  end if;
  if to_regclass('public.app_snapshot_history') is not null then
    execute 'drop policy if exists "snapshot_history_select_user" on app_snapshot_history';
    execute 'drop policy if exists "snapshot_history_insert_user" on app_snapshot_history';
    execute 'drop policy if exists "snapshot_history_delete_user" on app_snapshot_history';
  end if;
  if to_regclass('public.app_link_sets') is not null then
    execute 'drop policy if exists "link_sets_select_user" on app_link_sets';
    execute 'drop policy if exists "link_sets_insert_user" on app_link_sets';
    execute 'drop policy if exists "link_sets_delete_user" on app_link_sets';
  end if;
end $$;

drop function if exists is_not_anonymous();

drop table if exists app_link_sets;
drop table if exists app_snapshot_history;
drop table if exists app_snapshots;

-- Enable UUIDs
create extension if not exists "pgcrypto";

-- ===== Core Tables =====

-- Latest snapshot per user (app state + data)
create table if not exists app_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  namespace text not null default 'default',
  settings jsonb,
  telemetry jsonb,
  alarms jsonb,
  links jsonb,
  item_links jsonb,
  drawings jsonb,
  texts jsonb,
  notes jsonb,
  media_images jsonb,
  media_videos jsonb,
  history jsonb,
  telemetry_settings jsonb,
  alarm_settings jsonb,
  updated_at timestamptz default now()
);

-- Snapshot history (versioned)
create table if not exists app_snapshot_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  namespace text not null default 'default',
  label text,
  settings jsonb,
  telemetry jsonb,
  alarms jsonb,
  links jsonb,
  item_links jsonb,
  drawings jsonb,
  texts jsonb,
  notes jsonb,
  media_images jsonb,
  media_videos jsonb,
  history jsonb,
  telemetry_settings jsonb,
  alarm_settings jsonb,
  created_at timestamptz default now()
);

-- Portable link sets (per user, stored in Storage)
create table if not exists app_link_sets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  namespace text not null default 'default',
  label text,
  main_path text not null,
  mimic_path text not null,
  telemetry_path text not null,
  created_at timestamptz default now()
);

-- ===== Indexes =====
create index if not exists idx_snapshots_user_updated on app_snapshots(user_id, updated_at desc);
create index if not exists idx_snapshot_history_user_created on app_snapshot_history(user_id, created_at desc);
create index if not exists idx_link_sets_user_created on app_link_sets(user_id, created_at desc);

-- ===== RLS =====
alter table app_snapshots enable row level security;
alter table app_snapshot_history enable row level security;
alter table app_link_sets enable row level security;

-- Block anonymous users at RLS layer
create or replace function is_not_anonymous()
returns boolean
language sql stable as $$
  select coalesce((auth.jwt()->>'is_anonymous')::boolean, false) = false
$$;

-- app_snapshots policies
create policy "snapshots_select_user" on app_snapshots
  for select using (auth.uid() = user_id and is_not_anonymous());

create policy "snapshots_insert_user" on app_snapshots
  for insert with check (auth.uid() = user_id and is_not_anonymous());

create policy "snapshots_update_user" on app_snapshots
  for update using (auth.uid() = user_id and is_not_anonymous());

create policy "snapshots_delete_user" on app_snapshots
  for delete using (auth.uid() = user_id and is_not_anonymous());

-- app_snapshot_history policies
create policy "snapshot_history_select_user" on app_snapshot_history
  for select using (auth.uid() = user_id and is_not_anonymous());

create policy "snapshot_history_insert_user" on app_snapshot_history
  for insert with check (auth.uid() = user_id and is_not_anonymous());

create policy "snapshot_history_delete_user" on app_snapshot_history
  for delete using (auth.uid() = user_id and is_not_anonymous());

-- app_link_sets policies
create policy "link_sets_select_user" on app_link_sets
  for select using (auth.uid() = user_id and is_not_anonymous());

create policy "link_sets_insert_user" on app_link_sets
  for insert with check (auth.uid() = user_id and is_not_anonymous());

create policy "link_sets_delete_user" on app_link_sets
  for delete using (auth.uid() = user_id and is_not_anonymous());

-- ===== Storage Bucket =====
-- Default bucket name used in app: app_files
insert into storage.buckets (id, name, public)
values ('app_files', 'app_files', false)
on conflict do nothing;

-- Storage policies (owner = user, block anonymous)
drop policy if exists "app_files_read_user" on storage.objects;
drop policy if exists "app_files_insert_user" on storage.objects;
drop policy if exists "app_files_update_user" on storage.objects;
drop policy if exists "app_files_delete_user" on storage.objects;

create policy "app_files_read_user" on storage.objects
  for select using (
    bucket_id = 'app_files' and
    owner = auth.uid() and
    is_not_anonymous()
  );

create policy "app_files_insert_user" on storage.objects
  for insert with check (
    bucket_id = 'app_files' and
    owner = auth.uid() and
    is_not_anonymous()
  );

create policy "app_files_update_user" on storage.objects
  for update using (
    bucket_id = 'app_files' and
    owner = auth.uid() and
    is_not_anonymous()
  );

create policy "app_files_delete_user" on storage.objects
  for delete using (
    bucket_id = 'app_files' and
    owner = auth.uid() and
    is_not_anonymous()
  );