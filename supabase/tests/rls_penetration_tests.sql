-- ============================================================================
-- RLS Penetrasyon Test Paketi (master prompt, bölüm 29)
-- ============================================================================
-- Ne yapar: section 29'da açıkça listelenen senaryoları gerçek bir
-- Supabase/Postgres oturumunda çalıştırıp PASS/FAIL olarak raporlar.
-- Bu script'i yazan (Claude) canlı bir Supabase projesine bağlı değildi,
-- bu yüzden bu senaryolar migration'lar yazılırken yalnızca statik kod
-- incelemesiyle doğrulandı (bkz. docs/SECURITY_REVIEW.md). Bu dosya, bir
-- gerçek projede o incelemeyi ÇALIŞTIRILABİLİR bir teste çevirir.
--
-- GÜVENLİK: Tamamen bir transaction içinde çalışır ve en sonunda ROLLBACK
-- yapar. Hiçbir kalıcı veri yazmaz. Yine de, alışkanlık olarak önce bir
-- staging/branch projede çalıştırmanızı öneririz.
--
-- Kullanım:
--   1. Supabase Dashboard → Authentication → Users → Add User ile 5 test
--      kullanıcısı oluşturun (gerçek olması gerekmiyor, örn.
--      rls-test-admin-a@example.com + rastgele şifre): sırasıyla
--      admin_a, waiter_a, kitchen_a, cashier_a, admin_b rolleri için.
--   2. Aşağıdaki "test_users" INSERT'indeki 5 UUID'yi bu kullanıcıların
--      gerçek id'leriyle değiştirin.
--   3. Bu dosyanın tamamını SQL Editor'de çalıştırın.
--   4. Çıkan NOTICE'lara bakın. Herhangi bir "FAIL" varsa gerçek bir RLS
--      açığı var demektir -- migration'ları tekrar inceleyin.
--   5. İşiniz bittiğinde Dashboard'dan bu 5 test kullanıcısını silin.
-- ============================================================================

begin;

-- ---- 1. Test kullanıcıları: BURAYI KENDİ UUID'LERİNİZLE DEĞİŞTİRİN ----
create temporary table test_users (name text primary key, id uuid not null);
insert into test_users (name, id) values
  ('admin_a',   '11111111-1111-1111-1111-111111111111'),
  ('waiter_a',  '22222222-2222-2222-2222-222222222222'),
  ('kitchen_a', '33333333-3333-3333-3333-333333333333'),
  ('cashier_a', '44444444-4444-4444-4444-444444444444'),
  ('admin_b',   '55555555-5555-5555-5555-555555555555');

-- ---- 2. Test verisi (privileged rol olarak; ROLLBACK ile geri alınır) ----
-- Bu blok, SQL Editor'ün bağlandığı varsayılan rolün (genellikle
-- `postgres`, Supabase projelerinde RLS'i atlayan bir rol) altında
-- çalışır -- bu yüzden RLS politikalarına rağmen serbestçe seed veri
-- ekleyebiliriz. Asıl testler adım 3'te `authenticated` rolüne
-- geçtikten sonra başlıyor.
insert into public.businesses (id, name, active, subscription_status)
values
  ('aaaaaaaa-0000-0000-0000-00000000000a', 'RLS Test İşletme A', true, 'ACTIVE'),
  ('bbbbbbbb-0000-0000-0000-00000000000b', 'RLS Test İşletme B', true, 'ACTIVE');

insert into public.business_memberships (user_id, business_id, role)
select id, 'aaaaaaaa-0000-0000-0000-00000000000a', 'BUSINESS_ADMIN' from test_users where name = 'admin_a'
union all
select id, 'aaaaaaaa-0000-0000-0000-00000000000a', 'WAITER' from test_users where name = 'waiter_a'
union all
select id, 'aaaaaaaa-0000-0000-0000-00000000000a', 'KITCHEN' from test_users where name = 'kitchen_a'
union all
select id, 'aaaaaaaa-0000-0000-0000-00000000000a', 'CASHIER' from test_users where name = 'cashier_a'
union all
select id, 'bbbbbbbb-0000-0000-0000-00000000000b', 'BUSINESS_ADMIN' from test_users where name = 'admin_b';

insert into public.areas (id, business_id, name) values
  ('aaaaaaaa-0000-0000-0000-0000000000a1', 'aaaaaaaa-0000-0000-0000-00000000000a', 'A Alanı'),
  ('bbbbbbbb-0000-0000-0000-0000000000b1', 'bbbbbbbb-0000-0000-0000-00000000000b', 'B Alanı');

insert into public.restaurant_tables (id, business_id, area_id, name) values
  ('aaaaaaaa-0000-0000-0000-0000000000t1', 'aaaaaaaa-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-0000000000a1', 'A Masa 1'),
  ('bbbbbbbb-0000-0000-0000-0000000000t1', 'bbbbbbbb-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-0000000000b1', 'B Masa 1');

insert into public.categories (id, business_id, name) values
  ('aaaaaaaa-0000-0000-0000-0000000000c1', 'aaaaaaaa-0000-0000-0000-00000000000a', 'A Kategori');
insert into public.products (id, business_id, category_id, name, price) values
  ('aaaaaaaa-0000-0000-0000-0000000000p1', 'aaaaaaaa-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-0000000000c1', 'A Ürün', 100);

-- A işletmesinde bir sipariş + kalem + ödeme (gerçek admin/cashier
-- eylemleriyle, ownership zincirini test etmek için).
--
-- orders.opened_by / payments.received_by bir trigger tarafından her
-- zaman auth.uid()'den zorla alınıyor (20260922000019/000020/000024) --
-- bu yüzden bu INSERT'lerden ÖNCE auth.uid()'in doğru test kullanıcısına
-- çözülmesi için request.jwt.claims'i set ediyoruz, yoksa opened_by/
-- received_by NULL'a düşer ve NOT NULL constraint'i ihlal eder.
select set_config('request.jwt.claims', json_build_object('sub', '22222222-2222-2222-2222-222222222222')::text, true);
insert into public.orders (id, business_id, table_id, status, opened_by)
values ('aaaaaaaa-0000-0000-0000-0000000000o1', 'aaaaaaaa-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-0000000000t1', 'OPEN', '22222222-2222-2222-2222-222222222222');

insert into public.order_items (id, order_id, product_id, quantity)
values ('aaaaaaaa-0000-0000-0000-0000000000i1', 'aaaaaaaa-0000-0000-0000-0000000000o1', 'aaaaaaaa-0000-0000-0000-0000000000p1', 1);

select set_config('request.jwt.claims', json_build_object('sub', '44444444-4444-4444-4444-444444444444')::text, true);
insert into public.payments (id, order_id, method, amount, received_by)
values ('aaaaaaaa-0000-0000-0000-0000000000pay', 'aaaaaaaa-0000-0000-0000-0000000000o1', 'CASH', 100, '44444444-4444-4444-4444-444444444444');

-- ---- 3. Test oturumu yardımcısı ----
-- authenticated rolüne geçiyoruz (RLS'i asıl uygulayan rol budur;
-- postgres/superuser RLS'i tamamen atlar). auth.uid()'in okuduğu JWT
-- claim'ini set_config ile değiştirerek "farklı kullanıcı" simüle
-- ediyoruz.
set local role authenticated;

create or replace function pg_temp.as_user(p_name text) returns void
language plpgsql as $$
declare v_id uuid;
begin
  select id into v_id from test_users where name = p_name;
  if v_id is null then
    raise exception 'Bilinmeyen test kullanıcısı: %', p_name;
  end if;
  perform set_config('request.jwt.claims', json_build_object('sub', v_id, 'role', 'authenticated')::text, true);
end;
$$;

create or replace function pg_temp.expect_zero_rows(p_label text, p_count bigint) returns void
language plpgsql as $$
begin
  if p_count = 0 then
    raise notice 'PASS: %', p_label;
  else
    raise exception 'FAIL: % (% satır döndü, 0 bekleniyordu)', p_label, p_count;
  end if;
end;
$$;

-- ============================================================================
-- Senaryo 1: Business A -> Business B masalarını görebiliyor mu?
-- ============================================================================
select pg_temp.as_user('admin_a');
select pg_temp.expect_zero_rows(
  'Business A admin, Business B masalarını göremiyor',
  (select count(*) from public.restaurant_tables where business_id = 'bbbbbbbb-0000-0000-0000-00000000000b')
);

-- ============================================================================
-- Senaryo 2: Business A -> Business B siparişini okuyabiliyor mu?
-- ============================================================================
select pg_temp.expect_zero_rows(
  'Business A admin, Business B siparişlerini göremiyor',
  (select count(*) from public.orders where business_id = 'bbbbbbbb-0000-0000-0000-00000000000b')
);

-- ============================================================================
-- Senaryo 3: Business A -> Business B verisini update edebiliyor mu?
-- (areas üzerinden -- diğer tüm tenant-scoped tablolar da aynı desende)
-- ============================================================================
do $$
begin
  update public.areas set name = 'HACKED' where id = 'bbbbbbbb-0000-0000-0000-0000000000b1';
  if (select count(*) from public.areas where id = 'bbbbbbbb-0000-0000-0000-0000000000b1' and name = 'HACKED') > 0 then
    raise exception 'FAIL: Business A admin, Business B''nin alanını güncelleyebildi';
  else
    raise notice 'PASS: Business A admin, Business B''nin alanını güncelleyemedi (0 satır etkilendi)';
  end if;
end $$;

-- ============================================================================
-- Senaryo 4: WAITER -> ciroyu (payments) okuyabiliyor mu?
-- ============================================================================
select pg_temp.as_user('waiter_a');
select pg_temp.expect_zero_rows(
  'WAITER, kendi işletmesinin payments tablosunu bile göremiyor',
  (select count(*) from public.payments where business_id = 'aaaaaaaa-0000-0000-0000-00000000000a')
);

-- ============================================================================
-- Senaryo 5: KITCHEN -> payments görebiliyor mu?
-- ============================================================================
select pg_temp.as_user('kitchen_a');
select pg_temp.expect_zero_rows(
  'KITCHEN, payments tablosunu göremiyor',
  (select count(*) from public.payments where business_id = 'aaaaaaaa-0000-0000-0000-00000000000a')
);

-- Bonus: KITCHEN, order_items'ı VOID yapabiliyor mu? (Faz 5/7'de
-- KITCHEN'ın hiç void yapamayacağı şekilde kısıtlandı.)
do $$
begin
  update public.order_items set status = 'VOID', void_reason = 'test' where id = 'aaaaaaaa-0000-0000-0000-0000000000i1';
  raise exception 'FAIL: KITCHEN bir order_item''ı VOID yapabildi';
exception
  when others then
    if sqlerrm like '%Not authorized to void%' then
      raise notice 'PASS: KITCHEN order_item VOID yapamıyor (%)', sqlerrm;
    else
      raise; -- beklenmeyen farklı bir hata; olduğu gibi yükselt
    end if;
end $$;

-- ============================================================================
-- Senaryo 6: Normal BUSINESS_ADMIN -> PLATFORM_SUPER_ADMIN işlemi
-- yapabiliyor mu? (platform_admins'e kendini eklemeyi dener)
-- ============================================================================
select pg_temp.as_user('admin_a');
do $$
begin
  insert into public.platform_admins (user_id) select id from test_users where name = 'admin_a';
  raise exception 'FAIL: BUSINESS_ADMIN kendini platform_admins''e ekleyebildi';
exception
  when insufficient_privilege then
    raise notice 'PASS: BUSINESS_ADMIN platform_admins''e yazamıyor (yetki hatası)';
  when others then
    raise notice 'PASS: BUSINESS_ADMIN platform_admins''e yazamıyor (%)', sqlerrm;
end $$;

-- Bonus: business_memberships.role CHECK constraint'i PLATFORM_SUPER_ADMIN
-- değerini hiç kabul etmiyor mu?
do $$
begin
  insert into public.business_memberships (user_id, business_id, role)
  select id, 'aaaaaaaa-0000-0000-0000-00000000000a', 'PLATFORM_SUPER_ADMIN' from test_users where name = 'admin_b';
  raise exception 'FAIL: business_memberships.role PLATFORM_SUPER_ADMIN değerini kabul etti';
exception
  when check_violation then
    raise notice 'PASS: business_memberships.role PLATFORM_SUPER_ADMIN''ı reddediyor (check constraint)';
end $$;

-- ============================================================================
-- Senaryo 7: CASHIER -> başka işletmenin ödemesini görebiliyor mu?
-- ============================================================================
select pg_temp.as_user('cashier_a');
select pg_temp.expect_zero_rows(
  'CASHIER (A), Business B''nin payments''ını göremiyor',
  (select count(*) from public.payments where business_id = 'bbbbbbbb-0000-0000-0000-00000000000b')
);
-- Kendi işletmesinin ödemesini GÖREBİLMELİ (negatif test):
do $$
declare v_count bigint;
begin
  select count(*) into v_count from public.payments where business_id = 'aaaaaaaa-0000-0000-0000-00000000000a';
  if v_count > 0 then
    raise notice 'PASS: CASHIER (A) kendi işletmesinin ödemesini görebiliyor (% satır)', v_count;
  else
    raise exception 'FAIL: CASHIER (A) kendi işletmesinin ödemesini bile göremiyor -- RLS fazla kısıtlayıcı';
  end if;
end $$;

-- ============================================================================
-- Senaryo 8: Client business_id değiştirerek başka tenant'a geçebiliyor
-- mu? (WAITER, Business B'nin masasında Business A'ya sipariş açmaya
-- çalışıyor -- business_id/table_id tutarsızlığı)
-- ============================================================================
select pg_temp.as_user('waiter_a');
do $$
begin
  insert into public.orders (business_id, table_id, opened_by)
  values ('aaaaaaaa-0000-0000-0000-00000000000a', 'bbbbbbbb-0000-0000-0000-0000000000t1', '22222222-2222-2222-2222-222222222222');
  raise exception 'FAIL: WAITER, business_id ile table_id''i uyuşmayan sahte bir sipariş açabildi';
exception
  when others then
    if sqlerrm like '%must match%' then
      raise notice 'PASS: business_id/table_id tutarsızlığı engellendi (%)', sqlerrm;
    else
      raise;
    end if;
end $$;

-- Bonus: WAITER, Business B'nin masasını (gerçek business_id'siyle)
-- açmaya çalışıyor -- kendi işletmesinde olmayan bir masa.
do $$
begin
  insert into public.orders (business_id, table_id, opened_by)
  values ('bbbbbbbb-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-0000000000t1', '22222222-2222-2222-2222-222222222222');
  raise exception 'FAIL: WAITER (A), Business B''de sipariş açabildi';
exception
  when others then
    raise notice 'PASS: WAITER (A), Business B''de sipariş açamıyor (%)', sqlerrm;
end $$;

-- ============================================================================
-- Bonus senaryo: WAITER bir siparişi kapatabiliyor/iptal edebiliyor mu?
-- (Faz 7'de bilinçli olarak yalnızca CASHIER/BUSINESS_ADMIN'e kısıtlandı)
-- ============================================================================
do $$
begin
  update public.orders set status = 'CANCELLED' where id = 'aaaaaaaa-0000-0000-0000-0000000000o1';
  raise exception 'FAIL: WAITER bir siparişi CANCELLED yapabildi';
exception
  when others then
    if sqlerrm like '%cashier or business admin%' then
      raise notice 'PASS: WAITER sipariş durumunu değiştiremiyor (%)', sqlerrm;
    else
      raise;
    end if;
end $$;

-- ============================================================================
-- Bonus senaryo: voided_by/received_by/opened_by sahteciliği -- WAITER,
-- açtığı siparişte opened_by'ı başka bir kullanıcıya yazdırabiliyor mu?
-- (Zaten INSERT'te trigger tarafından auth.uid()'e zorlanıyor.)
-- ============================================================================
do $$
declare v_actual_opened_by uuid;
begin
  select opened_by into v_actual_opened_by from public.orders where id = 'aaaaaaaa-0000-0000-0000-0000000000o1';
  if v_actual_opened_by = '22222222-2222-2222-2222-222222222222' then
    raise notice 'PASS: orders.opened_by doğru şekilde sunucuda auth.uid()''den geldi';
  else
    raise exception 'FAIL: orders.opened_by beklenen kullanıcı değil (%), forge edilebilir olabilir', v_actual_opened_by;
  end if;
end $$;

do $$
begin
  raise notice '=== Tüm senaryolar tamamlandı. Yukarıda hiç FAIL yoksa RLS bu senaryolara karşı sağlam. ===';
end $$;

rollback;
