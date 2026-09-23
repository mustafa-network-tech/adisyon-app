-- Hosted Postgres keeps an ambient auth.uid() visible inside the nested
-- SECURITY DEFINER -> businesses guard call, even when the service-role test
-- clears the JWT immediately before invoking the Play verification RPC.  The
-- old guard treated auth.uid() IS NULL as the only machine-call signal, so a
-- legitimate verified subscription update could be rejected.
--
-- Give only the already service_role-restricted verification function a
-- narrowly scoped capability: while updating one business it sets a local
-- transaction marker containing that business id.  The guard accepts the
-- marker only while current_user is postgres (the enforced function owner).
-- An authenticated/anon caller cannot become postgres; setting a lookalike
-- custom GUC therefore cannot bypass the guard.

create or replace function public.restrict_business_update_to_admin_safe_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if public.is_platform_admin()
    or auth.uid() is null
    or (
      current_user = 'postgres'
      and current_setting(
        'app.trusted_subscription_update_business_id', true
      ) = new.id::text
    ) then
    return new;
  end if;

  if new.subscription_status is distinct from old.subscription_status
    or new.plan_id is distinct from old.plan_id
    or new.trial_started_at is distinct from old.trial_started_at
    or new.trial_ends_at is distinct from old.trial_ends_at
    or new.active is distinct from old.active then
    raise exception 'Only a platform admin may change subscription, plan, trial, or active status';
  end if;

  return new;
end;
$$;

create or replace function public.apply_google_play_verification_result(
  p_business_id uuid,
  p_plan_id uuid,
  p_product_id text,
  p_base_plan_id text,
  p_purchase_token text,
  p_order_id text,
  p_purchase_state text,
  p_auto_renewing boolean,
  p_start_time timestamptz,
  p_expiry_time timestamptz,
  p_raw_verification_response jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_plan_id uuid;
  v_new_subscription_status text;
  v_previous_update_context text;
begin
  v_plan_id := coalesce(
    p_plan_id,
    (
      select p.id
      from public.plans p
      where p.google_play_product_id = p_product_id
        and p_base_plan_id in (
          p.google_play_monthly_base_plan_id,
          p.google_play_yearly_base_plan_id
        )
      limit 1
    )
  );

  insert into public.google_play_purchases (
    business_id, plan_id, product_id, base_plan_id, purchase_token, order_id,
    purchase_state, auto_renewing, start_time, expiry_time, last_verified_at,
    raw_verification_response
  )
  values (
    p_business_id, v_plan_id, p_product_id, p_base_plan_id, p_purchase_token,
    p_order_id, p_purchase_state, p_auto_renewing, p_start_time,
    p_expiry_time, now(), coalesce(p_raw_verification_response, '{}'::jsonb)
  )
  on conflict (purchase_token) do update set
    plan_id = excluded.plan_id,
    base_plan_id = excluded.base_plan_id,
    order_id = excluded.order_id,
    purchase_state = excluded.purchase_state,
    auto_renewing = excluded.auto_renewing,
    start_time = excluded.start_time,
    expiry_time = excluded.expiry_time,
    last_verified_at = now(),
    raw_verification_response = excluded.raw_verification_response
  returning id into v_id;

  v_new_subscription_status := case p_purchase_state
    when 'ACTIVE' then 'ACTIVE'
    when 'GRACE_PERIOD' then 'GRACE_PERIOD'
    when 'ON_HOLD' then 'EXPIRED'
    when 'CANCELLED' then
      case when p_expiry_time > now() then 'ACTIVE' else 'CANCELLED' end
    when 'EXPIRED' then 'EXPIRED'
    when 'REVOKED' then 'EXPIRED'
    else null
  end;

  if v_new_subscription_status is not null then
    v_previous_update_context := current_setting(
      'app.trusted_subscription_update_business_id', true
    );
    perform set_config(
      'app.trusted_subscription_update_business_id',
      p_business_id::text,
      true
    );

    begin
      update public.businesses
      set subscription_status = v_new_subscription_status,
          plan_id = coalesce(v_plan_id, plan_id)
      where id = p_business_id;
    exception when others then
      perform set_config(
        'app.trusted_subscription_update_business_id',
        coalesce(v_previous_update_context, ''),
        true
      );
      raise;
    end;

    perform set_config(
      'app.trusted_subscription_update_business_id',
      coalesce(v_previous_update_context, ''),
      true
    );
  end if;

  perform app_private.write_audit_event(
    p_business_id,
    'GOOGLE_PLAY_SUBSCRIPTION_VERIFIED',
    'google_play_purchases',
    v_id,
    jsonb_build_object('product_id', p_product_id, 'purchase_state', p_purchase_state)
  );

  return v_id;
end;
$$;

alter function public.apply_google_play_verification_result(
  uuid, uuid, text, text, text, text, text, boolean, timestamptz, timestamptz, jsonb
) owner to postgres;

revoke execute on function public.apply_google_play_verification_result(
  uuid, uuid, text, text, text, text, text, boolean, timestamptz, timestamptz, jsonb
) from public, anon, authenticated;
grant execute on function public.apply_google_play_verification_result(
  uuid, uuid, text, text, text, text, text, boolean, timestamptz, timestamptz, jsonb
) to service_role;
