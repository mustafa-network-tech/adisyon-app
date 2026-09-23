-- ============================================================================
-- Deneme süresi ayarı + Google Play hak (entitlement) test paketi
-- (20260925000032_trial_settings_and_play_entitlement)
-- ============================================================================
-- Tek transaction, sonunda ROLLBACK; kalıcı veri yazmaz. SQL Editor'de
-- postgres olarak, rol taklidi kapalıyken çalıştırın. Önkoşul:
-- rls_penetration_tests.sql'deki 5 test kullanıcısı auth.users'ta olmalı.
-- Herhangi bir FAIL exception olarak durur.
-- ============================================================================

begin;

reset role;
select set_config('request.jwt.claim.sub', '', true),
       set_config('request.jwt.claim.role', '', true),
       set_config('request.jwt.claims', '', true);

-- Kalıcı test kurulumundaki rolleri bu transaction içinde nötrle
-- (ROLLBACK geri getirir): platform yöneticiliği ve kitchen/cashier/waiter
-- kullanıcılarının mevcut işletme üyelikleri. Böylece bu kullanıcılar
-- create_own_business ile sıfırdan işletme açabilir.
delete from public.platform_admins where user_id in (
  'eecceeb6-504e-4a75-813b-99f19b61841b', '7d4ec330-d7e7-4d18-b394-9b1b26f68b9f',
  'a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb', 'c0d2e232-69a0-48f3-be90-aac2f3957034',
  'a96dbfd3-8265-4840-a47a-9dbde237269e'
);
delete from public.business_memberships where user_id in (
  '7d4ec330-d7e7-4d18-b394-9b1b26f68b9f', 'a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb',
  'c0d2e232-69a0-48f3-be90-aac2f3957034'
);
-- admin_a bu pakette platform yöneticisi olarak kullanılır.
insert into public.platform_admins (user_id) values ('eecceeb6-504e-4a75-813b-99f19b61841b');

-- Varsayılan değere sabitle (production'da ayar değiştirilmiş olabilir).
update public.subscription_settings set app_trial_days = 3, trial_plan_code = 'ultra_super';

-- Play eşlemesi (yalnızca bu transaction için).
update public.plans set google_play_product_id = 'test_standard',
  google_play_monthly_base_plan_id = 'monthly', google_play_yearly_base_plan_id = 'yearly'
where code = 'standard';
update public.plans set google_play_product_id = 'test_super',
  google_play_monthly_base_plan_id = 'monthly', google_play_yearly_base_plan_id = 'yearly'
where code = 'super';

create or replace function pg_temp.as_user(p_id uuid) returns void
language plpgsql as $$
begin
  if p_id is null then
    perform set_config('request.jwt.claim.sub', '', true);
    perform set_config('request.jwt.claims', '', true);
  else
    perform set_config('request.jwt.claim.sub', p_id::text, true);
    perform set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
  end if;
end;
$$;
grant execute on function pg_temp.as_user(uuid) to authenticated, anon, service_role;

create temp table t_ids (k text primary key, v uuid) on commit drop;
grant all on t_ids to authenticated, anon, service_role;

-- ---------------------------------------------------------------------------
-- 1) Varsayılan ayar ve yetkiler
-- ---------------------------------------------------------------------------
do $$
begin
  if (select app_trial_days from public.subscription_settings) <> 3 then
    raise exception 'FAIL: varsayılan uygulama denemesi 3 gün değil';
  end if;
  if (select default_value from (
        select column_default as default_value from information_schema.columns
        where table_schema = 'public' and table_name = 'subscription_settings' and column_name = 'app_trial_days'
      ) d) <> '3' then
    raise exception 'FAIL: app_trial_days sütun varsayılanı 3 değil';
  end if;
  raise warning 'PASS: varsayılan uygulama denemesi 3 gün';
end $$;

set local role authenticated;

do $$
declare v_rows integer;
begin
  -- İşletme yöneticisi / normal kullanıcı (admin_b) değiştiremez.
  perform pg_temp.as_user('a96dbfd3-8265-4840-a47a-9dbde237269e');
  update public.subscription_settings set app_trial_days = 30;
  get diagnostics v_rows = row_count;
  if v_rows <> 0 then
    raise exception 'FAIL: normal kullanıcı deneme süresini değiştirebildi';
  end if;
  raise warning 'PASS: normal kullanıcı deneme süresini değiştiremiyor';

  -- Platform yöneticisi değiştirebilir.
  perform pg_temp.as_user('eecceeb6-504e-4a75-813b-99f19b61841b');
  update public.subscription_settings set app_trial_days = 7;
  get diagnostics v_rows = row_count;
  if v_rows <> 1 or (select app_trial_days from public.subscription_settings) <> 7 then
    raise exception 'FAIL: Süper Admin deneme süresini değiştiremedi';
  end if;
  update public.subscription_settings set app_trial_days = 3;
  raise warning 'PASS: Süper Admin deneme süresini değiştirebiliyor';
end $$;

do $$
begin
  perform pg_temp.as_user('eecceeb6-504e-4a75-813b-99f19b61841b');
  insert into public.subscription_settings (id, app_trial_days) values (false, 30);
  raise exception 'FAIL: ayarlara ikinci satır eklenebildi';
exception when insufficient_privilege or check_violation or unique_violation then
  raise warning 'PASS: ayar tablosuna satır eklenemiyor';
end $$;

reset role;
set local role anon;
do $$
declare v_rows integer;
begin
  update public.subscription_settings set app_trial_days = 30;
  get diagnostics v_rows = row_count;
  raise exception 'FAIL: anon ayarı güncelleyebildi (% satır)', v_rows;
exception when insufficient_privilege then
  raise warning 'PASS: anon deneme ayarını değiştiremiyor';
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- 2) create_own_business ayarı sunucuda okur
-- ---------------------------------------------------------------------------
set local role authenticated;
do $$
declare v_id uuid; v_ends timestamptz; v_started timestamptz;
begin
  perform pg_temp.as_user('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb'); -- kitchen_a
  v_id := public.create_own_business('Deneme 3 Gün');
  insert into t_ids values ('biz3', v_id);
  select trial_started_at, trial_ends_at into v_started, v_ends from public.businesses where id = v_id;
  if v_ends - v_started <> interval '3 days' then
    raise exception 'FAIL: 3 günlük deneme bekleniyordu, fark: %', v_ends - v_started;
  end if;
  raise warning 'PASS: yeni işletme 3 günlük deneme aldı (ayardan)';
end $$;

do $$
begin
  perform pg_temp.as_user('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb');
  perform public.create_own_business('İkinci İşletme');
  raise exception 'FAIL: aynı kullanıcı ikinci işletmeyle yeni deneme alabildi';
exception when others then
  if sqlerrm not like 'BUSINESS_ALREADY_EXISTS%' then raise; end if;
  raise warning 'PASS: ikinci işletmeyle yeni deneme alınamıyor';
end $$;
reset role;

-- Ayar 0'a çekilir: eski deneme değişmez, yeni işletme deneme almaz.
select pg_temp.as_user('eecceeb6-504e-4a75-813b-99f19b61841b');
set local role authenticated;
update public.subscription_settings set app_trial_days = 0;
reset role;

set local role authenticated;
do $$
declare v_id uuid; v_old_ends interval; v_ent record;
begin
  select trial_ends_at - trial_started_at into v_old_ends from public.businesses where id = (select v from t_ids where k = 'biz3');
  if v_old_ends <> interval '3 days' then
    raise exception 'FAIL: ayar değişikliği mevcut denemeyi değiştirdi (%)', v_old_ends;
  end if;
  raise warning 'PASS: ayar değişikliği mevcut denemeleri etkilemiyor';

  perform pg_temp.as_user('c0d2e232-69a0-48f3-be90-aac2f3957034'); -- cashier_a
  v_id := public.create_own_business('Deneme 0 Gün');
  insert into t_ids values ('biz0', v_id);
  if public.business_is_operational(v_id) then
    raise exception 'FAIL: 0 gün ayarında yeni işletme operasyonel';
  end if;
  select * into v_ent from public.get_business_entitlement(v_id);
  if v_ent.access_source <> 'NONE' or v_ent.app_trial_days_left <> 0 then
    raise exception 'FAIL: 0 gün ayarında entitlement beklenmedik (% / %)', v_ent.access_source, v_ent.app_trial_days_left;
  end if;
  raise warning 'PASS: 0 gün ayarında uygulama denemesi verilmiyor (abonelik gerekli)';
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- 3) Deneme süresince en üst plan hakları; entitlement sunucu saatiyle
-- ---------------------------------------------------------------------------
select pg_temp.as_user('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb');
insert into public.areas (id, business_id, name)
select gen_random_uuid(), v, 'Alan ' || g from t_ids, generate_series(1, 5) g where k = 'biz3';

do $$
declare v_biz uuid := (select v from t_ids where k = 'biz3'); v_area uuid; i integer; v_ent record;
begin
  select id into v_area from public.areas where business_id = v_biz limit 1;
  for i in 1..35 loop
    insert into public.restaurant_tables (business_id, area_id, name) values (v_biz, v_area, 'M' || i);
  end loop;
  begin
    insert into public.restaurant_tables (business_id, area_id, name) values (v_biz, v_area, 'M36');
    raise exception 'FAIL: deneme sırasında Ultra Süper limiti (35 masa) aşıldı';
  exception when others then
    if sqlerrm not like 'PLAN_LIMIT_EXCEEDED%' then raise; end if;
  end;
  raise warning 'PASS: uygulama denemesinde Ultra Süper hakları (5 alan, 35 masa) geçerli';

  select * into v_ent from public.get_business_entitlement(v_biz);
  if v_ent.access_source <> 'APP_TRIAL' or v_ent.effective_plan_code <> 'ultra_super'
     or v_ent.app_trial_days_left <> 3 or not v_ent.qr_menu_enabled then
    raise exception 'FAIL: deneme entitlement beklenmedik (%, %, %, %)',
      v_ent.access_source, v_ent.effective_plan_code, v_ent.app_trial_days_left, v_ent.qr_menu_enabled;
  end if;
  raise warning 'PASS: entitlement sunucu saatiyle 3 gün kaldı, efektif plan Ultra Süper, QR açık';
end $$;

select pg_temp.as_user(null);
set local role anon;
do $$
begin
  if (select count(*) from public.get_qr_menu_business((select v from t_ids where k = 'biz3'))) <> 1 then
    raise exception 'FAIL: deneme sırasında QR menü kapalı';
  end if;
  raise warning 'PASS: deneme sırasında QR menü açık';
end $$;
reset role;

-- Başka işletmenin entitlement'ı okunamaz.
set local role authenticated;
do $$
begin
  perform pg_temp.as_user('a96dbfd3-8265-4840-a47a-9dbde237269e');
  if (select count(*) from public.get_business_entitlement((select v from t_ids where k = 'biz3'))) <> 0 then
    raise exception 'FAIL: başka işletmenin abonelik durumu okunabildi';
  end if;
  raise warning 'PASS: başka işletmenin abonelik durumu okunamıyor';
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- 4) Deneme biter: yeni adisyon açılamaz
-- ---------------------------------------------------------------------------
select pg_temp.as_user(null);
update public.businesses set trial_ends_at = now() - interval '1 minute'
where id = (select v from t_ids where k = 'biz3');

set local role authenticated;
do $$
declare v_biz uuid := (select v from t_ids where k = 'biz3'); v_table uuid;
begin
  perform pg_temp.as_user('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb');
  select id into v_table from public.restaurant_tables where business_id = v_biz limit 1;
  insert into public.orders (business_id, table_id) values (v_biz, v_table);
  raise exception 'FAIL: deneme bittikten sonra yeni adisyon açılabildi';
exception when others then
  if sqlerrm not like 'TRIAL_OR_SUBSCRIPTION_INACTIVE%' then raise; end if;
  raise warning 'PASS: deneme bitince yeni adisyon açılamıyor';
end $$;

-- İstemci kendini ücretli plana geçiremez / sahte Play sonucu yazamaz.
do $$
begin
  perform pg_temp.as_user('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb');
  update public.businesses set subscription_status = 'ACTIVE',
    plan_id = (select id from public.plans where code = 'ultra_super')
  where id = (select v from t_ids where k = 'biz3');
  raise exception 'FAIL: işletme yöneticisi kendini aktif/Ultra yapabildi';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  raise warning 'PASS: işletme yöneticisi abonelik durumunu/planını değiştiremiyor';
end $$;

do $$
begin
  perform pg_temp.as_user('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb');
  perform public.record_google_play_subscription(
    (select v from t_ids where k = 'biz3'), 'test_super', 'monthly', 'forged', null, null,
    'ACTIVE', true, false, now(), now() + interval '1 month', '{}'::jsonb);
  raise exception 'FAIL: authenticated sahte Play sonucu yazabildi';
exception when insufficient_privilege then
  raise warning 'PASS: authenticated record_google_play_subscription çağıramıyor';
end $$;

do $$
begin
  perform pg_temp.as_user('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb');
  perform public.apply_google_play_verification_result(
    (select v from t_ids where k = 'biz3'), null, 'test_super', 'monthly', 'forged-old', null,
    'ACTIVE', true, now(), now() + interval '1 month', '{}'::jsonb);
  raise exception 'FAIL: authenticated eski Play RPC''sini çağırabildi';
exception when insufficient_privilege then
  raise warning 'PASS: authenticated apply_google_play_verification_result çağıramıyor';
end $$;
reset role;

set local role anon;
do $$
begin
  perform public.record_google_play_subscription(
    (select v from t_ids where k = 'biz3'), 'test_super', 'monthly', 'forged-anon', null, null,
    'ACTIVE', true, false, now(), now() + interval '1 month', '{}'::jsonb);
  raise exception 'FAIL: anon sahte Play sonucu yazabildi';
exception when insufficient_privilege then
  raise warning 'PASS: anon record_google_play_subscription çağıramıyor';
end $$;
do $$
begin
  perform public.apply_google_play_verification_result(
    (select v from t_ids where k = 'biz3'), null, 'test_super', 'monthly', 'forged-anon-old', null,
    'ACTIVE', true, now(), now() + interval '1 month', '{}'::jsonb);
  raise exception 'FAIL: anon eski Play RPC''sini çağırabildi';
exception when insufficient_privilege then
  raise warning 'PASS: anon apply_google_play_verification_result çağıramıyor';
end $$;
do $$
begin
  perform public.business_effective_plan_id((select v from t_ids where k = 'biz3'));
  raise exception 'FAIL: anon iç yardımcı fonksiyonu çağırabildi';
exception when insufficient_privilege then
  raise warning 'PASS: iç yardımcı business_effective_plan_id istemciye kapalı';
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- 5) Play (service role yolu): ücretsiz dönem = en üst plan, sonra kendi planı
-- ---------------------------------------------------------------------------
select pg_temp.as_user(null);
set local role service_role;
do $$
declare v_biz uuid := (select v from t_ids where k = 'biz3'); v_r record;
begin
  select * into v_r from public.record_google_play_subscription(
    v_biz, 'test_standard', 'monthly', 'tok-standard-1', null, 'GPA.1',
    'ACTIVE', true, true, now(), now() + interval '15 days', '{}'::jsonb);
  if v_r.business_status <> 'ACTIVE' or v_r.subscribed_plan_code <> 'standard' then
    raise exception 'FAIL: Play aboneliği işletmeyi aktif etmedi (%, %)', v_r.business_status, v_r.subscribed_plan_code;
  end if;
  if not public.business_is_operational(v_biz) then
    raise exception 'FAIL: aktif Play aboneliğinde işletme operasyonel değil';
  end if;
  raise warning 'PASS: aktif Play aboneliğiyle işletme kullanılabiliyor';
end $$;
reset role;

do $$
declare v_biz uuid := (select v from t_ids where k = 'biz3'); v_ent record;
begin
  perform pg_temp.as_user('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb');
  select * into v_ent from public.get_business_entitlement(v_biz);
  if v_ent.access_source <> 'PLAY_TRIAL' or v_ent.effective_plan_code <> 'ultra_super'
     or v_ent.subscribed_plan_code <> 'standard' then
    raise exception 'FAIL: Play ücretsiz döneminde en üst plan hakları yok (%, %, %)',
      v_ent.access_source, v_ent.effective_plan_code, v_ent.subscribed_plan_code;
  end if;
  raise warning 'PASS: Play ücretsiz döneminde Standart abonelikte Ultra Süper hakları geçerli';
end $$;

select pg_temp.as_user(null);
set local role service_role;
do $$
declare v_biz uuid := (select v from t_ids where k = 'biz3');
begin
  perform public.record_google_play_subscription(
    v_biz, 'test_standard', 'monthly', 'tok-standard-1', null, 'GPA.1..0',
    'ACTIVE', true, false, now(), now() + interval '1 month', '{}'::jsonb);
end $$;
reset role;

do $$
declare v_biz uuid := (select v from t_ids where k = 'biz3'); v_area uuid; v_ent record;
begin
  perform pg_temp.as_user('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb');
  select * into v_ent from public.get_business_entitlement(v_biz);
  if v_ent.access_source <> 'PLAY_SUBSCRIPTION' or v_ent.effective_plan_code <> 'standard' then
    raise exception 'FAIL: ücretli dönemde efektif plan Standart değil (%, %)', v_ent.access_source, v_ent.effective_plan_code;
  end if;
  select id into v_area from public.areas where business_id = v_biz limit 1;
  begin
    insert into public.restaurant_tables (business_id, area_id, name) values (v_biz, v_area, 'Fazla');
    raise exception 'FAIL: ücretli Standart dönemde limit üstü masa eklenebildi';
  exception when others then
    if sqlerrm not like 'PLAN_LIMIT_EXCEEDED%' then raise; end if;
  end;
  raise warning 'PASS: ücretli dönemde Standart limitleri geçerli (mevcut kayıtlar korunur, yenisi engellenir)';
end $$;

select pg_temp.as_user(null);
set local role anon;
do $$
begin
  if (select count(*) from public.get_qr_menu_business((select v from t_ids where k = 'biz3'))) <> 0 then
    raise exception 'FAIL: Standart ücretli dönemde QR menü açık';
  end if;
  raise warning 'PASS: QR menü yalnızca uygun plan + aktif abonelikte';
end $$;
reset role;

-- ---------------------------------------------------------------------------
-- 6) Token başka işletmeye bağlanamaz; değiştirilen eski abonelik yenisini kapatamaz
-- ---------------------------------------------------------------------------
set local role service_role;
do $$
begin
  perform public.record_google_play_subscription(
    (select v from t_ids where k = 'biz0'), 'test_standard', 'monthly', 'tok-standard-1', null, null,
    'ACTIVE', true, false, now(), now() + interval '1 month', '{}'::jsonb);
  raise exception 'FAIL: başka işletmenin purchase token''ı bu işletmeye bağlanabildi';
exception when others then
  if sqlerrm not like 'PURCHASE_TOKEN_BELONGS_TO_OTHER_BUSINESS%' then raise; end if;
  raise warning 'PASS: purchase token başka işletmeye bağlanamıyor';
end $$;

do $$
begin
  perform public.record_google_play_subscription(
    (select v from t_ids where k = 'biz3'), 'uydurma_urun', 'monthly', 'tok-unknown', null, null,
    'ACTIVE', true, false, now(), now() + interval '1 month', '{}'::jsonb);
  raise exception 'FAIL: bilinmeyen Play ürünü kabul edildi';
exception when others then
  if sqlerrm not like 'UNKNOWN_PLAY_PRODUCT%' then raise; end if;
  raise warning 'PASS: plan eşlemesi olmayan Play ürünü reddediliyor';
end $$;

do $$
declare v_biz uuid := (select v from t_ids where k = 'biz3'); v_r record;
begin
  -- Standart -> Süper yükseltmesi: yeni token eskisini linked olarak taşır.
  perform public.record_google_play_subscription(
    v_biz, 'test_super', 'monthly', 'tok-super-1', 'tok-standard-1', 'GPA.2',
    'ACTIVE', true, false, now(), now() + interval '1 month', '{}'::jsonb);
  -- Eski abonelik sonra EXPIRED bildirimi alır.
  select * into v_r from public.record_google_play_subscription(
    v_biz, 'test_standard', 'monthly', 'tok-standard-1', null, 'GPA.1..0',
    'EXPIRED', false, false, now() - interval '1 month', now() - interval '1 minute', '{}'::jsonb);
  if v_r.business_status <> 'ACTIVE' or v_r.subscribed_plan_code <> 'super' then
    raise exception 'FAIL: değiştirilen eski aboneliğin bitişi yenisini kapattı (%, %)', v_r.business_status, v_r.subscribed_plan_code;
  end if;
  raise warning 'PASS: plan değişikliğinde eski aboneliğin bitişi yeni aboneliği etkilemiyor';

  -- Yeni abonelik de biterse işletme EXPIRED olur.
  select * into v_r from public.record_google_play_subscription(
    v_biz, 'test_super', 'monthly', 'tok-super-1', 'tok-standard-1', 'GPA.2',
    'EXPIRED', false, false, now() - interval '1 month', now() - interval '1 minute', '{}'::jsonb);
  if v_r.business_status <> 'EXPIRED' or public.business_is_operational(v_biz) then
    raise exception 'FAIL: abonelik bitince işletme hâlâ aktif (%)', v_r.business_status;
  end if;
  raise warning 'PASS: abonelik bitince yeni adisyon kapanıyor';
end $$;
reset role;

-- Askıya alınmış işletmeyi Play açamaz.
select pg_temp.as_user(null);
update public.businesses set subscription_status = 'SUSPENDED' where id = (select v from t_ids where k = 'biz0');
set local role service_role;
do $$
declare v_r record;
begin
  select * into v_r from public.record_google_play_subscription(
    (select v from t_ids where k = 'biz0'), 'test_super', 'yearly', 'tok-susp', null, null,
    'ACTIVE', true, false, now(), now() + interval '1 year', '{}'::jsonb);
  if v_r.business_status <> 'SUSPENDED' then
    raise exception 'FAIL: Play askıdaki işletmeyi açtı (%)', v_r.business_status;
  end if;
  raise warning 'PASS: Super Admin askısı Play tarafından aşılamıyor';
end $$;
reset role;

do $$
begin
  raise warning '=== Deneme/entitlement senaryoları tamamlandı. ===';
end $$;

rollback;
