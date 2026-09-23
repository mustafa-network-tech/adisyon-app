-- ============================================================================
-- 20260924000031_trusted_subscription_update_context uygulandi mi?
-- Salt okunur; production SQL Editor'de postgres olarak calistirin.
-- ============================================================================

do $$
declare
  v_owner text;
  v_role text;
begin
  if not exists (
    select 1
    from pg_proc
    where oid = 'public.restrict_business_update_to_admin_safe_fields()'::regprocedure
      and prosrc like '%app.trusted_subscription_update_business_id%'
      and prosrc like '%current_user = ''postgres''%'
  ) then
    raise exception 'FAIL: businesses guard guvenilir Play guncelleme baglamini tanimiyor';
  end if;
  raise warning 'PASS: businesses guard hedef isletme + postgres baglamini birlikte dogruluyor';

  select r.rolname into v_owner
  from pg_proc p
  join pg_roles r on r.oid = p.proowner
  where p.oid = 'public.apply_google_play_verification_result(uuid,uuid,text,text,text,text,text,boolean,timestamptz,timestamptz,jsonb)'::regprocedure;

  if v_owner <> 'postgres' then
    raise exception 'FAIL: Play dogrulama fonksiyonunun sahibi postgres degil (%)', v_owner;
  end if;

  if not exists (
    select 1
    from pg_proc
    where oid = 'public.apply_google_play_verification_result(uuid,uuid,text,text,text,text,text,boolean,timestamptz,timestamptz,jsonb)'::regprocedure
      and prosecdef
      and prosrc like '%set_config(%app.trusted_subscription_update_business_id%'
      and prosrc like '%app_private.write_audit_event%'
  ) then
    raise exception 'FAIL: Play dogrulama fonksiyonu guvenilir update/audit yolunu kullanmiyor';
  end if;
  raise warning 'PASS: Play dogrulama fonksiyonu postgres sahibi ve guvenilir update/audit yolunda';

  foreach v_role in array array['anon', 'authenticated'] loop
    if has_function_privilege(
      v_role,
      'public.apply_google_play_verification_result(uuid,uuid,text,text,text,text,text,boolean,timestamptz,timestamptz,jsonb)',
      'execute'
    ) then
      raise exception 'FAIL: % rolu Play dogrulama fonksiyonunu cagirabiliyor', v_role;
    end if;
  end loop;
  if not has_function_privilege(
    'service_role',
    'public.apply_google_play_verification_result(uuid,uuid,text,text,text,text,text,boolean,timestamptz,timestamptz,jsonb)',
    'execute'
  ) then
    raise exception 'FAIL: service_role Play dogrulama fonksiyonunu cagiramiyor';
  end if;
  raise warning 'PASS: yalnizca service_role Play dogrulama fonksiyonunu cagirabiliyor';

  raise warning '=== 20260924000031 tamamen uygulanmis. ===';
end $$;
