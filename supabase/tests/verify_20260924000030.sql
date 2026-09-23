-- ============================================================================
-- 20260924000030_internal_audit_writer uygulandi mi? (salt okunur)
-- ============================================================================
-- Production SQL Editor'de postgres olarak calistirin. Veri yazmaz.
-- ============================================================================

do $$
declare
  v_count integer;
  v_callable boolean;
  v_role text;
begin
  if to_regprocedure(
    'app_private.write_audit_event(uuid,text,text,uuid,jsonb)'
  ) is null then
    raise exception 'FAIL: ic audit yazma fonksiyonu yok';
  end if;

  select p.prosecdef and r.rolname = 'postgres'
    into v_callable
  from pg_proc p
  join pg_roles r on r.oid = p.proowner
  where p.oid = 'app_private.write_audit_event(uuid,text,text,uuid,jsonb)'::regprocedure;

  if not coalesce(v_callable, false) then
    raise exception 'FAIL: ic audit yazari SECURITY DEFINER/postgres sahibi degil';
  end if;
  raise warning 'PASS: ic audit yazari SECURITY DEFINER ve postgres sahibi';

  foreach v_role in array array['anon', 'authenticated', 'service_role'] loop
    if has_schema_privilege(v_role, 'app_private', 'usage')
      or has_function_privilege(
        v_role,
        'app_private.write_audit_event(uuid,text,text,uuid,jsonb)',
        'execute'
      ) then
      raise exception 'FAIL: % rolu ic audit yazarina erisebiliyor', v_role;
    end if;
  end loop;
  raise warning 'PASS: anon/authenticated/service_role ic audit yazarini dogrudan cagiramiyor';

  select count(*) into v_count
  from pg_proc
  where proname in (
    'audit_payment_void',
    'audit_order_item_void',
    'audit_order_cancel',
    'audit_business_membership_insert',
    'audit_business_membership_update',
    'audit_business_admin_fields_update',
    'restrict_business_application_review'
  )
    and prosecdef
    and prosrc like '%app_private.write_audit_event%'
    and prosrc not like '%public.log_audit_event%';

  if v_count <> 7 then
    raise exception 'FAIL: audit trigger fonksiyonlarinin tamami ic yazari kullanmiyor (% / 7)', v_count;
  end if;
  raise warning 'PASS: 7 audit trigger fonksiyonu yalnizca ic yazari kullaniyor';

  select count(*) into v_count
  from pg_proc
  where proname in ('create_own_business', 'apply_google_play_verification_result')
    and prosecdef
    and prosrc like '%app_private.write_audit_event%';

  if v_count <> 2 then
    raise exception 'FAIL: guvenilir RPC audit cagrilari guncel degil (% / 2)', v_count;
  end if;
  raise warning 'PASS: guvenilir RPC audit cagrilari ic yazari kullaniyor';

  foreach v_role in array array['anon', 'authenticated'] loop
    if has_function_privilege(
      v_role,
      'public.log_audit_event(uuid,text,text,uuid,jsonb)',
      'execute'
    ) then
      raise exception 'FAIL: % rolu log_audit_event cagirabiliyor', v_role;
    end if;
    if has_function_privilege(
      v_role,
      'public.apply_google_play_verification_result(uuid,uuid,text,text,text,text,text,boolean,timestamptz,timestamptz,jsonb)',
      'execute'
    ) then
      raise exception 'FAIL: % rolu Play dogrulama sonucunu yazabiliyor', v_role;
    end if;
  end loop;
  raise warning 'PASS: istemci rolleri public audit/Play RPC fonksiyonlarini cagiramiyor';

  raise warning '=== 20260924000030 tamamen uygulanmis. ===';
end $$;
