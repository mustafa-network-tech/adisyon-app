-- Extensions required by the schema.
-- pgcrypto provides gen_random_uuid(); Supabase enables it by default,
-- but we declare it explicitly so migrations are portable.
create extension if not exists pgcrypto with schema extensions;
