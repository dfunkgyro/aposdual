# Supabase Schema

This project uses Supabase for per-user sync and portable link sharing.

## What this schema does

- Stores per-user snapshots and snapshot history.
- Stores per-user portable link sets in Postgres and the actual files in Storage.
- Blocks anonymous (guest) users from reading/writing Supabase data.
- Keeps guest users local-only, while authenticated users can sync across devices.

## Tables

- `app_snapshots`: latest per-user snapshot.
- `app_snapshot_history`: versioned snapshots per user.
- `app_link_sets`: per-user link history; points to Storage paths.

## Storage

- Bucket: `app_files` (default).
- Each file is stored under: `user_id/links/<timestamp>-<type>.<ext>`.

## RLS behavior

All tables are protected by RLS. Policies only allow access for
`auth.uid() = user_id` and block anonymous sessions.

## Guest vs Authenticated

- Guest login (anonymous) keeps local file paths only.
- Authenticated users can upload portable links and sync the latest link set.

## Optional config

Set in `assets/.env`:

```
SUPABASE_STORAGE_BUCKET=app_files
```

## Migration note

If you have old rows without `user_id`, they will not be visible under RLS.
You can backfill `user_id` for a specific user if needed.