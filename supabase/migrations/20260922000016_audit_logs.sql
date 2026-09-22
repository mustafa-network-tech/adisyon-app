-- audit_logs: append-only. No UPDATE/DELETE policy exists for anyone,
-- and there is no direct client INSERT policy either -- rows are only
-- ever written via public.log_audit_event(), a SECURITY DEFINER RPC,
-- so application code (web/mobile) records events without ever being
-- able to forge the actor_id (it is always taken from auth.uid()).
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles (id),
  business_id uuid references public.businesses (id),
  action text not null,
  entity text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index idx_audit_logs_business on public.audit_logs (business_id);
create index idx_audit_logs_entity on public.audit_logs (entity, entity_id);

alter table public.audit_logs enable row level security;
alter table public.audit_logs force row level security;

create policy audit_logs_select
  on public.audit_logs for select
  to authenticated
  using (
    public.is_platform_admin()
    or (business_id is not null and public.has_business_role(business_id, array['BUSINESS_ADMIN']))
  );

-- Deliberately no insert/update/delete policy: writes only happen via
-- the SECURITY DEFINER function below, which runs with elevated
-- privilege and is not subject to these row policies.

create or replace function public.log_audit_event(
  p_business_id uuid,
  p_action text,
  p_entity text,
  p_entity_id uuid,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if p_business_id is not null
    and not (public.is_platform_admin() or public.is_business_member(p_business_id)) then
    raise exception 'Not authorized to log an audit event for this business';
  end if;

  insert into public.audit_logs (actor_id, business_id, action, entity, entity_id, metadata)
  values (auth.uid(), p_business_id, p_action, p_entity, p_entity_id, coalesce(p_metadata, '{}'::jsonb))
  returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.log_audit_event(uuid, text, text, uuid, jsonb) to authenticated;
