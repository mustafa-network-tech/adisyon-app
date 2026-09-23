-- ============================================================================
-- Plan / abonelik test paketi (20260923000029_plan_catalog_and_billing_fixes)
-- ============================================================================
-- Plan kataloğu, yıllık fiyat hesabı, plan limitleri (aktifleştirme ve rol
-- değişikliği dahil), tek işletme kuralı, Google Play durum eşlemesi ve
-- RPC yetkilerini doğrular. rls_penetration_tests.sql ile aynı düzen:
-- tek transaction, sonunda ROLLBACK, kalıcı veri yazmaz.
--
-- Kullanım: rls_penetration_tests.sql'deki 5 test kullanıcısı auth.users'ta
-- olmalı (bkz. setup_test_users.sql). SQL Editor'de postgres olarak çalıştırın;
-- herhangi bir FAIL exception olarak durur.
-- ============================================================================

begin;

-- ---- Oturum kimliğini sıfırla ----
-- SQL Editor oturumu önceden bir kullanıcı kimliği taşıyabilir (rol
-- taklidi veya daha önce oturum düzeyinde set edilmiş
-- request.jwt.claim.sub / request.jwt.claims). auth.uid() bunları okur ve
-- claim.sub'a öncelik verir; temizlenmezse aşağıdaki kurulum verisi bu
-- kullanıcı adına yazılır ve audit trigger'ı "Not authorized to log an
-- audit event" hatasıyla durur. Kurulum, kullanıcı oturumu olmadan
-- (service role gibi) çalışmalı.
reset role;
select set_config('request.jwt.claim.sub', '', true),
       set_config('request.jwt.claim.role', '', true),
       set_config('request.jwt.claims', '', true);

-- ---- Kalıcı test rollerini nötrle ----
-- setup_test_users.sql admin_a'yı platform süper yöneticisi yapar; bu
-- senaryolar ise onu sıradan bir işletme yöneticisi olarak kullanır
-- (platform yöneticisi her işletmeyi görebilir ve plan değiştirebilir --
-- bu beklenen davranıştır, açık değil). Satır yalnızca bu transaction
-- içinde silinir; sondaki ROLLBACK geri getirir.
delete from public.platform_admins
where user_id in (
  'eecceeb6-504e-4a75-813b-99f19b61841b',
  '7d4ec330-d7e7-4d18-b394-9b1b26f68b9f',
  'a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb',
  'c0d2e232-69a0-48f3-be90-aac2f3957034',
  'a96dbfd3-8265-4840-a47a-9dbde237269e'
);

-- ---- Test verisi (privileged rol) ----
insert into public.businesses (id, name, active, subscription_status, plan_id)
values (
  'cccccccc-0000-0000-0000-00000000000c', 'Plan Test İşletme', true, 'ACTIVE',
  (select id from public.plans where code = 'standard')
);

insert into public.business_memberships (user_id, business_id, role)
values ('eecceeb6-504e-4a75-813b-99f19b61841b', 'cccccccc-0000-0000-0000-00000000000c', 'BUSINESS_ADMIN');

insert into public.areas (id, business_id, name)
values ('cccccccc-0000-0000-0000-0000000000a1', 'cccccccc-0000-0000-0000-00000000000c', 'Salon');

-- 1) Katalog ve yıllık fiyat
do $$
declare v_count integer;
begin
  select count(*) into v_count from public.plans
  where (code, monthly_price, yearly_price, yearly_discount, max_tables, max_waiters, max_areas, qr_menu_enabled) in (
    ('standard', 399, 4309.20, 10, 10, 2, 1, false),
    ('super', 799, 8629.20, 10, 20, 5, 3, false),
    ('ultra_super', 1899, 20509.20, 10, 35, 10, 5, true)
  );
  if v_count <> 3 then
    raise exception 'FAIL: plan kataloğu/yıllık fiyatlar beklenen değerde değil (% / 3)', v_count;
  end if;
  raise warning 'PASS: 3 plan ve yıllık fiyatlar (4309.20 / 8629.20 / 20509.20) doğru';

  select count(*) into v_count from public.plan_billing_options where plan_code in ('standard', 'super', 'ultra_super');
  if v_count <> 6 then
    raise exception 'FAIL: plan_billing_options 6 satır bekleniyordu, % döndü', v_count;
  end if;
  raise warning 'PASS: plan_billing_options her plan için aylık + yıllık satır veriyor';
end $$;

-- 2) Yıllık fiyat istemciden elle girilemez, her zaman hesaplanır
do $$
declare v_yearly numeric;
begin
  update public.plans set yearly_price = 1 where code = 'standard';
  select yearly_price into v_yearly from public.plans where code = 'standard';
  if v_yearly <> 4309.20 then
    raise exception 'FAIL: yearly_price elle değiştirilebildi (%)', v_yearly;
  end if;
  raise warning 'PASS: yearly_price her zaman aylık x 12 - indirimden hesaplanıyor';
end $$;

-- 3) Aynı base plan kimliği farklı ürünlerde kullanılabilir (Play modeli)
do $$
begin
  update public.plans set google_play_product_id = 'test_product_standard',
    google_play_monthly_base_plan_id = 'monthly', google_play_yearly_base_plan_id = 'yearly'
  where code = 'standard';
  update public.plans set google_play_product_id = 'test_product_super',
    google_play_monthly_base_plan_id = 'monthly', google_play_yearly_base_plan_id = 'yearly'
  where code = 'super';
  raise warning 'PASS: farklı ürünlerde aynı base plan kimliği kabul edildi';
end $$;

-- Masa/personel güncelleme guard'ları işletme yöneticisi oturumu ister.
select set_config('request.jwt.claim.sub', 'eecceeb6-504e-4a75-813b-99f19b61841b', true),
       set_config('request.jwt.claims', json_build_object('sub', 'eecceeb6-504e-4a75-813b-99f19b61841b', 'role', 'authenticated')::text, true);

-- 4) Masa limiti: ekleme + yeniden aktifleştirme
do $$
declare i integer;
begin
  for i in 1..10 loop
    insert into public.restaurant_tables (business_id, area_id, name)
    values ('cccccccc-0000-0000-0000-00000000000c', 'cccccccc-0000-0000-0000-0000000000a1', 'Masa ' || i);
  end loop;

  begin
    insert into public.restaurant_tables (business_id, area_id, name)
    values ('cccccccc-0000-0000-0000-00000000000c', 'cccccccc-0000-0000-0000-0000000000a1', 'Masa 11');
    raise exception 'FAIL: Standart planda 11. masa eklenebildi';
  exception when others then
    if sqlerrm not like 'PLAN_LIMIT_EXCEEDED%' then raise; end if;
    raise warning 'PASS: Standart planda 11. masa engellendi';
  end;

  update public.restaurant_tables set active = false
  where business_id = 'cccccccc-0000-0000-0000-00000000000c' and name = 'Masa 1';
  insert into public.restaurant_tables (business_id, area_id, name)
  values ('cccccccc-0000-0000-0000-00000000000c', 'cccccccc-0000-0000-0000-0000000000a1', 'Masa 11');

  begin
    update public.restaurant_tables set active = true
    where business_id = 'cccccccc-0000-0000-0000-00000000000c' and name = 'Masa 1';
    raise exception 'FAIL: pasif masa yeniden aktif edilerek limit aşıldı';
  exception when others then
    if sqlerrm not like 'PLAN_LIMIT_EXCEEDED%' then raise; end if;
    raise warning 'PASS: pasif masayı yeniden aktif ederek limit aşılamıyor';
  end;

  -- Limitle ilgisi olmayan güncellemeler etkilenmez.
  update public.restaurant_tables set name = 'Masa 2b'
  where business_id = 'cccccccc-0000-0000-0000-00000000000c' and name = 'Masa 2';
  raise warning 'PASS: limitteyken masa adı güncellenebiliyor';
end $$;

-- 5) Alan limiti (Standart = 1 alan)
do $$
begin
  insert into public.areas (business_id, name) values ('cccccccc-0000-0000-0000-00000000000c', 'Bahçe');
  raise exception 'FAIL: Standart planda 2. alan eklenebildi';
exception when others then
  if sqlerrm not like 'PLAN_LIMIT_EXCEEDED%' then raise; end if;
  raise warning 'PASS: Standart planda 2. alan engellendi';
end $$;

-- 6) Garson limiti: ekleme + rol değişikliği (Standart = 2 garson)
do $$
begin
  insert into public.business_memberships (user_id, business_id, role) values
    ('7d4ec330-d7e7-4d18-b394-9b1b26f68b9f', 'cccccccc-0000-0000-0000-00000000000c', 'WAITER'),
    ('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb', 'cccccccc-0000-0000-0000-00000000000c', 'WAITER'),
    ('c0d2e232-69a0-48f3-be90-aac2f3957034', 'cccccccc-0000-0000-0000-00000000000c', 'CASHIER');

  begin
    update public.business_memberships set role = 'WAITER'
    where business_id = 'cccccccc-0000-0000-0000-00000000000c'
      and user_id = 'c0d2e232-69a0-48f3-be90-aac2f3957034';
    raise exception 'FAIL: rol WAITER yapılarak garson limiti aşıldı';
  exception when others then
    if sqlerrm not like 'PLAN_LIMIT_EXCEEDED%' then raise; end if;
    raise warning 'PASS: rol değişikliğiyle garson limiti aşılamıyor';
  end;

  -- Mevcut bir garsonun başka alanı güncellenince limit tekrar tetiklenmez.
  update public.business_memberships set active = true
  where business_id = 'cccccccc-0000-0000-0000-00000000000c'
    and user_id = '7d4ec330-d7e7-4d18-b394-9b1b26f68b9f';
  raise warning 'PASS: limitteki mevcut garsonun güncellenmesi engellenmiyor';
end $$;

-- 7) Google Play durum eşlemesi (gerçek service_role, kullanıcı oturumu yok)
-- Hosted SQL Editor statement'lar arasında önceki JWT claim'ini koruyabilir.
-- Rolü ve claims bağlamını Play doğrulama çağrısıyla aynı blokta kurarak hem
-- gerçek production çağrısını taklit eder hem de guard trigger'ının yanlışlıkla
-- önceki BUSINESS_ADMIN kimliğini görmesini engelleriz.
set local role service_role;

do $$
declare v_status text; v_plan text;
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claim.role', 'service_role', true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('role', 'service_role')::text,
    true
  );
  if auth.uid() is not null then
    raise exception 'FAIL: service_role test bağlamında auth.uid() NULL değil (%)', auth.uid();
  end if;

  perform public.apply_google_play_verification_result(
    'cccccccc-0000-0000-0000-00000000000c', null, 'test_product_super', 'yearly',
    'test-token-1', 'GPA.test-1', 'ACTIVE', true, now(), now() + interval '1 year', '{}'::jsonb);
  select b.subscription_status, p.code into v_status, v_plan
  from public.businesses b join public.plans p on p.id = b.plan_id
  where b.id = 'cccccccc-0000-0000-0000-00000000000c';
  if v_status <> 'ACTIVE' or v_plan <> 'super' then
    raise exception 'FAIL: ACTIVE doğrulaması beklenen sonucu vermedi (%, %)', v_status, v_plan;
  end if;
  raise warning 'PASS: plan, Play ürün/base plan bilgisinden sunucuda çözüldü (super)';

  perform public.apply_google_play_verification_result(
    'cccccccc-0000-0000-0000-00000000000c', null, 'test_product_super', 'yearly',
    'test-token-1', 'GPA.test-1', 'CANCELLED', false, now(), now() + interval '10 days', '{}'::jsonb);
  select subscription_status into v_status from public.businesses where id = 'cccccccc-0000-0000-0000-00000000000c';
  if v_status <> 'ACTIVE' then
    raise exception 'FAIL: iptal edilmiş ama süresi dolmamış abonelik erişimi kesti (%)', v_status;
  end if;
  raise warning 'PASS: iptal edilen abonelik süre sonuna kadar aktif kalıyor';

  perform public.apply_google_play_verification_result(
    'cccccccc-0000-0000-0000-00000000000c', null, 'test_product_super', 'yearly',
    'test-token-1', 'GPA.test-1', 'GRACE_PERIOD', true, now(), now() + interval '3 days', '{}'::jsonb);
  if not public.business_is_operational('cccccccc-0000-0000-0000-00000000000c') then
    raise exception 'FAIL: GRACE_PERIOD işletmeyi durdurdu';
  end if;
  raise warning 'PASS: GRACE_PERIOD sırasında yeni sipariş açılabiliyor';

  perform public.apply_google_play_verification_result(
    'cccccccc-0000-0000-0000-00000000000c', null, 'test_product_super', 'yearly',
    'test-token-1', 'GPA.test-1', 'ON_HOLD', true, now(), now() - interval '1 day', '{}'::jsonb);
  if public.business_is_operational('cccccccc-0000-0000-0000-00000000000c') then
    raise exception 'FAIL: ON_HOLD durumunda işletme hâlâ operasyonel';
  end if;
  raise warning 'PASS: ON_HOLD erişimi kapatıyor';

  -- Test sonrası işletmeyi tekrar aktif et (sonraki senaryolar için).
  update public.businesses set subscription_status = 'ACTIVE' where id = 'cccccccc-0000-0000-0000-00000000000c';
end $$;

-- ---- authenticated oturumu ----
reset role;
set local role authenticated;

create or replace function pg_temp.as_user(p_id uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', p_id::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
end;
$$;

-- 8) Doğrulama RPC'si istemciden çağrılamaz
do $$
begin
  perform pg_temp.as_user('eecceeb6-504e-4a75-813b-99f19b61841b');
  perform public.apply_google_play_verification_result(
    'cccccccc-0000-0000-0000-00000000000c', (select id from public.plans where code = 'ultra_super'),
    'x', 'x', 'forged-token', null, 'ACTIVE', true, now(), now() + interval '1 year', '{}'::jsonb);
  raise exception 'FAIL: authenticated kullanıcı apply_google_play_verification_result çağırabildi';
exception when insufficient_privilege then
  raise warning 'PASS: authenticated kullanıcı Play doğrulama sonucunu yazamıyor';
end $$;

-- 9) log_audit_event istemciden çağrılamaz
do $$
begin
  perform pg_temp.as_user('eecceeb6-504e-4a75-813b-99f19b61841b');
  perform public.log_audit_event('cccccccc-0000-0000-0000-00000000000c', 'FAKE', 'x', null, '{}'::jsonb);
  raise exception 'FAIL: authenticated kullanıcı log_audit_event çağırabildi';
exception when insufficient_privilege then
  raise warning 'PASS: authenticated kullanıcı sahte denetim kaydı yazamıyor';
end $$;

-- 10) İşletme yöneticisi kendi planını değiştiremez
do $$
begin
  perform pg_temp.as_user('eecceeb6-504e-4a75-813b-99f19b61841b');
  update public.businesses set plan_id = (select id from public.plans where code = 'ultra_super')
  where id = 'cccccccc-0000-0000-0000-00000000000c';
  raise exception 'FAIL: işletme yöneticisi kendi planını Ultra Süper yapabildi';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  raise warning 'PASS: işletme yöneticisi planını değiştiremiyor (%)', sqlerrm;
end $$;

-- 10b) İşletme yöneticisi (authenticated rolü, RLS + trigger'lar) normal
-- personel ekleyebilir ve audit kaydı trigger tarafından yazılır.
do $$
declare v_membership_id uuid; v_audit_count integer;
begin
  perform pg_temp.as_user('eecceeb6-504e-4a75-813b-99f19b61841b');
  insert into public.business_memberships (user_id, business_id, role)
  values ('a96dbfd3-8265-4840-a47a-9dbde237269e', 'cccccccc-0000-0000-0000-00000000000c', 'KITCHEN')
  returning id into v_membership_id;

  select count(*) into v_audit_count from public.audit_logs
  where entity_id = v_membership_id and action = 'STAFF_INVITED'
    and actor_id = 'eecceeb6-504e-4a75-813b-99f19b61841b';
  if v_audit_count <> 1 then
    raise exception 'FAIL: personel eklendi ama STAFF_INVITED audit kaydı oluşmadı (%)', v_audit_count;
  end if;
  raise warning 'PASS: işletme yöneticisi personel ekleyebiliyor, audit kaydı trigger ile yazıldı';
end $$;

-- 11) Tek işletme kuralı
do $$
begin
  perform pg_temp.as_user('eecceeb6-504e-4a75-813b-99f19b61841b');
  perform public.create_own_business('İkinci İşletme');
  raise exception 'FAIL: aynı kullanıcı ikinci işletmeyi (ve ikinci denemeyi) açabildi';
exception when others then
  if sqlerrm not like 'BUSINESS_ALREADY_EXISTS%' then raise; end if;
  raise warning 'PASS: kullanıcı başına tek self-servis işletme';
end $$;

-- ---- anon ----
-- Önceki bloklardan kalan kullanıcı kimliğini temizle: anon'un kimliği
-- yoktur ve aşağıdaki "reset role" sonrası kurulum adımları da kullanıcı
-- oturumu olmadan çalışmalı.
select set_config('request.jwt.claim.sub', '', true), set_config('request.jwt.claims', '', true);
set local role anon;

-- 12) anon da log_audit_event çağıramaz
do $$
begin
  perform public.log_audit_event('cccccccc-0000-0000-0000-00000000000c', 'FAKE', 'x', null, '{}'::jsonb);
  raise exception 'FAIL: anon log_audit_event çağırabildi';
exception when insufficient_privilege then
  raise warning 'PASS: anon sahte denetim kaydı yazamıyor';
end $$;

-- 12b) anon (herkese açık anahtar) Play doğrulama sonucunu yazamaz.
-- 20260923000029 öncesinde bu çağrı başarılıydı: anon'un auth.uid()'i
-- null olduğu için işletme guard trigger'ı da devreye girmiyordu.
do $$
begin
  perform public.apply_google_play_verification_result(
    'cccccccc-0000-0000-0000-00000000000c', (select id from public.plans where code = 'ultra_super'),
    'x', 'x', 'forged-anon-token', null, 'ACTIVE', true, now(), now() + interval '1 year', '{}'::jsonb);
  raise exception 'FAIL: anon apply_google_play_verification_result çağırabildi';
exception when insufficient_privilege then
  raise warning 'PASS: anon Play doğrulama sonucunu yazamıyor';
end $$;

-- 13) QR menü: yalnızca QR içeren plan + operasyonel işletme
do $$
declare v_count integer;
begin
  select count(*) into v_count from public.get_qr_menu_business('cccccccc-0000-0000-0000-00000000000c');
  if v_count <> 0 then
    raise exception 'FAIL: QR menü içermeyen planda QR menü göründü';
  end if;
  raise warning 'PASS: QR menü içermeyen planda QR menü kapalı';
end $$;

reset role;
update public.businesses set plan_id = (select id from public.plans where code = 'ultra_super')
where id = 'cccccccc-0000-0000-0000-00000000000c';
set local role anon;

do $$
declare v_count integer;
begin
  select count(*) into v_count from public.get_qr_menu_business('cccccccc-0000-0000-0000-00000000000c');
  if v_count <> 1 then
    raise exception 'FAIL: Ultra Süper planında QR menü görünmedi';
  end if;
  raise warning 'PASS: Ultra Süper planında QR menü açık';
end $$;

reset role;
update public.businesses set subscription_status = 'EXPIRED' where id = 'cccccccc-0000-0000-0000-00000000000c';
set local role anon;

do $$
declare v_count integer;
begin
  select count(*) into v_count from public.get_qr_menu_business('cccccccc-0000-0000-0000-00000000000c');
  if v_count <> 0 then
    raise exception 'FAIL: süresi dolmuş işletmenin QR menüsü hâlâ açık';
  end if;
  raise warning 'PASS: süresi dolan işletmenin QR menüsü kapanıyor';
end $$;

do $$
begin
  raise warning '=== Plan/abonelik senaryoları tamamlandı. ===';
end $$;

rollback;
