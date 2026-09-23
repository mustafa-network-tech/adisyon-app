-- ============================================================================
-- 20260925000032_trial_settings_and_play_entitlement uygulandı mı? (salt okunur)
-- ============================================================================
-- Production'da SQL Editor'de postgres olarak çalıştırın. Hiçbir veri yazmaz.
-- Eksik bir parça varsa FAIL ile durur.
-- ============================================================================

do $$
declare
  v_count integer;
  v_days integer;
  v_callable boolean;
  v_fn text;
  v_role text;
  function_is_callable_by constant text :=
    'select exists (select 1 from pg_proc p, aclexplode(coalesce(p.proacl, acldefault(''f'', p.proowner))) a '
    'where p.oid = $1::regprocedure and a.privilege_type = ''EXECUTE'' '
    'and (a.grantee = 0 or a.grantee = (select oid from pg_roles where rolname = $2)))';
begin
  -- 1) Ayar tablosu ve varsayılan satır
  if to_regclass('public.subscription_settings') is null then
    raise exception 'FAIL: subscription_settings tablosu yok';
  end if;
  select count(*), max(app_trial_days) into v_count, v_days from public.subscription_settings;
  if v_count <> 1 then
    raise exception 'FAIL: subscription_settings tek satır olmalı (% satır)', v_count;
  end if;
  raise warning 'PASS: subscription_settings var (uygulama denemesi: % gün, deneme planı: %)',
    v_days, (select trial_plan_code from public.subscription_settings);

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'subscription_settings'
      and policyname = 'subscription_settings_update_platform_admin'
  ) then
    raise exception 'FAIL: ayar güncelleme politikası yok';
  end if;
  if has_table_privilege('anon', 'public.subscription_settings', 'update')
     or has_table_privilege('authenticated', 'public.subscription_settings', 'insert')
     or has_table_privilege('authenticated', 'public.subscription_settings', 'delete') then
    raise exception 'FAIL: subscription_settings yazma yetkileri fazla açık';
  end if;
  raise warning 'PASS: ayar yalnızca platform yöneticisi tarafından güncellenebilir';

  -- 2) Play satın alma sütunları
  select count(*) into v_count from information_schema.columns
  where table_schema = 'public' and table_name = 'google_play_purchases'
    and column_name in ('in_free_trial', 'linked_purchase_token');
  if v_count <> 2 then raise exception 'FAIL: google_play_purchases yeni sütunları eksik'; end if;
  raise warning 'PASS: google_play_purchases.in_free_trial / linked_purchase_token var';

  -- 3) Fonksiyon gövdeleri
  if not exists (select 1 from pg_proc where proname = 'create_own_business' and prosrc like '%subscription_settings%') then
    raise exception 'FAIL: create_own_business deneme süresini ayardan okumuyor';
  end if;
  if not exists (select 1 from pg_proc where proname = 'enforce_plan_limit' and prosrc like '%business_effective_plan_id%' and prosecdef) then
    raise exception 'FAIL: enforce_plan_limit efektif planı kullanmıyor';
  end if;
  if not exists (select 1 from pg_proc where proname = 'get_qr_menu_business' and prosrc like '%business_effective_plan_id%') then
    raise exception 'FAIL: QR menü efektif planı kullanmıyor';
  end if;
  raise warning 'PASS: fonksiyon gövdeleri güncel';

  -- 4) Yetkiler
  foreach v_fn in array array[
    'public.record_google_play_subscription(uuid,text,text,text,text,text,text,boolean,boolean,timestamptz,timestamptz,jsonb)',
    'public.apply_google_play_verification_result(uuid,uuid,text,text,text,text,text,boolean,timestamptz,timestamptz,jsonb)',
    'public.business_effective_plan_id(uuid)',
    'public.log_audit_event(uuid,text,text,uuid,jsonb)'
  ] loop
    foreach v_role in array array['anon', 'authenticated'] loop
      execute function_is_callable_by into v_callable using v_fn, v_role;
      if v_callable then
        raise exception 'FAIL: % rolü (veya PUBLIC) % fonksiyonunu çağırabiliyor', v_role, v_fn;
      end if;
    end loop;
  end loop;
  raise warning 'PASS: anon/authenticated/PUBLIC Play yazma ve iç yardımcı fonksiyonları çağıramıyor';

  if not has_function_privilege('service_role',
      'public.record_google_play_subscription(uuid,text,text,text,text,text,text,boolean,boolean,timestamptz,timestamptz,jsonb)',
      'execute') then
    raise exception 'FAIL: service_role record_google_play_subscription çağıramıyor';
  end if;
  execute function_is_callable_by into v_callable using 'public.get_business_entitlement(uuid)', 'anon';
  if v_callable then raise exception 'FAIL: anon get_business_entitlement çağırabiliyor'; end if;
  if not has_function_privilege('authenticated', 'public.get_business_entitlement(uuid)', 'execute') then
    raise exception 'FAIL: authenticated get_business_entitlement çağıramıyor';
  end if;
  raise warning 'PASS: service_role Play yazma yolunu, authenticated entitlement okumasını kullanabiliyor';

  raise warning '=== 20260925000032 tamamen uygulanmış. ===';
end $$;
