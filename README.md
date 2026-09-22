# MK Adisyon — Web

Production web repository for MK Adisyon: a multi-tenant restaurant/cafe
order & POS SaaS. Next.js app covering the Platform Super Admin panel and
the PC Kasa/POS screen, backed by Supabase (Postgres + Auth + Realtime).

This is a deliberately web-only export of the main MK Adisyon monorepo --
the Flutter/Android app (waiter, kitchen, business admin mobile) lives in
a separate repository and is not part of this codebase.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and
[docs/SECURITY_REVIEW.md](docs/SECURITY_REVIEW.md) for the full
architecture, and [supabase/migrations](supabase/migrations) for the
database schema and RLS policies (source of truth, applied in filename
order).

## Layout

```
apps/web/      Next.js app (Platform Super Admin, PC Kasa/POS, auth)
supabase/      Database migrations (source of truth for schema/RLS)
docs/          Architecture & security review docs
```

## Local development

```
cd apps/web
cp .env.local.example .env.local   # fill in real Supabase values
npm install
npm run dev
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

## Deployment

Deployed to Vercel from `apps/web` (set as the project's Root Directory).
See the project's deployment notes for required environment variables
and the Supabase Auth Site URL/Redirect URL configuration.
