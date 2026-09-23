-- ============================================================================
-- 20260923000029_plan_catalog_and_billing_fixes uygulandı mı? (salt okunur)
-- ============================================================================
-- Production'da SQL Editor'de postgres olarak çalıştırın. Hiçbir veri
-- yazmaz. Eksik bir parça varsa FAIL ile durur; hepsi PASS ise migration
-- tamamen uygulanmıştır.
-- ============================================================================

do $$
declare
  v_count integer;

  function_is_callable_by constant text :=
    'select exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault(''f'', p.proowner))) a '
    'where p.oid = $1::regprocedure and a.privilege_type = ''EXECUTE'' '
    'and (a.grantee = 0 or a.grantee = (select oid from pg_roles where rolname = $2)))';
  v_callable boolean;
  v_fn text;
  v_role text;
begin
  -- 1) Şema
  select count(*) into v_count from information_schema.columns
  where table_schema = 'public' and table_name = 'plans' and column_name in ('code', 'sort_order');
  if v_count <> 2 then raise exception 'FAIL: plans.code / plans.sort_order yok'; end if;

  if to_regclass('public.plan_billing_options') is null then
    raise exception 'FAIL: plan_billing_options görünümü yok';
  end if;

  select count(*) into v_count from pg_trigger
  where not tgisinternal and tgname in (
    'trg_plans_compute_yearly_price',
    'trg_areas_enforce_plan_limit_on_update',
    'trg_restaurant_tables_enforce_plan_limit_on_update',
    'trg_business_memberships_enforce_plan_limit_on_update'
  );
  if v_count <> 4 then raise exception 'FAIL: 029 trigger''ları eksik (% / 4)', v_count; end if;
  raise warning 'PASS: şema (plans.code, plan_billing_options, 4 trigger)';

  -- 2) Plan verisi
  select count(*) into v_count from public.plans
  where (code, monthly_price, yearly_price) in (
    ('standard', 399, 4309.20), ('super', 799, 8629.20), ('ultra_super', 1899, 20509.20)
  );
  if v_count <> 3 then raise exception 'FAIL: 3 plan / yıllık fiyatlar beklenen değerde değil (% / 3)', v_count; end if;
  raise warning 'PASS: 3 plan ve yıllık fiyatlar';

  -- 3) Fonksiyon gövdeleri güncel mi?
  if not exists (select 1 from pg_proc where proname = 'create_own_business' and prosrc like '%BUSINESS_ALREADY_EXISTS%') then
    raise exception 'FAIL: create_own_business tek işletme kuralını içermiyor';
  end if;
  if not exists (select 1 from pg_proc where proname = 'business_is_operational' and prosrc like '%GRACE_PERIOD%') then
    raise exception 'FAIL: business_is_operational GRACE_PERIOD''u içermiyor';
  end if;
  if not exists (select 1 from pg_proc where proname = 'apply_google_play_verification_result' and prosrc like '%when ''ON_HOLD'' then ''EXPIRED''%') then
    raise exception 'FAIL: apply_google_play_verification_result eski durum eşlemesini kullanıyor';
  end if;
  raise warning 'PASS: fonksiyon gövdeleri güncel';

  -- 4) EXECUTE yetkileri: PUBLIC (grantee 0) dahil, istemci rolleri çağıramamalı
  foreach v_fn in array array[
    'public.log_audit_event(uuid,text,text,uuid,jsonb)',
    'public.apply_google_play_verification_result(uuid,uuid,text,text,text,text,text,boolean,timestamptz,timestamptz,jsonb)'
  ] loop
    foreach v_role in array array['anon', 'authenticated'] loop
      execute function_is_callable_by into v_callable using v_fn, v_role;
      if v_callable then
        raise exception 'FAIL: % rolü (veya PUBLIC) % fonksiyonunu çağırabiliyor', v_role, v_fn;
      end if;
    end loop;
  end loop;
  raise warning 'PASS: anon/authenticated/PUBLIC log_audit_event ve apply_google_play_verification_result çağıramıyor';

  if not has_function_privilege('service_role',
      'public.apply_google_play_verification_result(uuid,uuid,text,text,text,text,text,boolean,timestamptz,timestamptz,jsonb)',
      'execute') then
    raise exception 'FAIL: service_role apply_google_play_verification_result çağıramıyor';
  end if;
  raise warning 'PASS: service_role doğrulama fonksiyonunu çağırabiliyor';

  -- 5) Audit trigger'ları hâlâ SECURITY DEFINER (log_audit_event'i sahibi olarak çağırır)
  select count(*) into v_count from pg_proc
  where proname in ('audit_business_membership_insert', 'audit_business_membership_update',
                    'audit_business_admin_fields_update', 'audit_payment_void',
                    'audit_order_item_void', 'audit_order_cancel')
    and prosecdef;
  if v_count <> 6 then raise exception 'FAIL: audit trigger fonksiyonlarından SECURITY DEFINER olmayan var (% / 6)', v_count; end if;
  raise warning 'PASS: 6 audit trigger fonksiyonu SECURITY DEFINER';

  raise warning '=== 20260923000029 tamamen uygulanmış. ===';
end $$;
