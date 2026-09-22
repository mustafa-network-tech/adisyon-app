# MK Adisyon

Multi-tenant restaurant/cafe order & POS SaaS. Single Supabase (Postgres)
backend shared by a Next.js web app (cashier/POS, business admin,
platform super admin, kitchen) and a Flutter Android app (waiter,
kitchen, cashier, business admin).

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full architecture
and [supabase/migrations](supabase/migrations) for the database schema
and RLS policies (Faz 1).

## Layout

```
apps/web/      Next.js app (scaffolded in Faz 2)
apps/mobile/   Flutter app (scaffolded in Faz 4)
supabase/      Database migrations (source of truth for schema/RLS)
docs/          Architecture & planning docs
```

## Applying migrations

Requires the [Supabase CLI](https://supabase.com/docs/guides/cli):

```
npm install -g supabase
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
```

Or paste the files under `supabase/migrations/` into the Supabase
Dashboard SQL editor, in filename order.

After the first real user signs up, bootstrap the first platform admin
manually (no client-facing way to do this, by design):

```sql
insert into public.platform_admins (user_id) values ('<auth-user-uuid>');
```
