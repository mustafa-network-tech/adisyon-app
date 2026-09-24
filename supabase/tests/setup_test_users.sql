-- MK Adisyon kalici test kullanicisi kurulumu.
-- Bu dosya migration degildir. Yalnizca test/staging ortaminda,
-- Supabase SQL Editor uzerinden postgres yetkisiyle calistirin.
-- Tekrar calistirilabilir: her calismada asagidaki rol esleme durumuna getirir.
--
-- Test kullanicilari:
--   eecceeb6-504e-4a75-813b-99f19b61841b = PLATFORM_SUPER_ADMIN (isletme uyeligi yok)
--   7d4ec330-d7e7-4d18-b394-9b1b26f68b9f = BUSINESS_ADMIN
--   c0d2e232-69a0-48f3-be90-aac2f3957034 = CASHIER
--   a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb = KITCHEN
--   a96dbfd3-8265-4840-a47a-9dbde237269e = WAITER
-- Isletme rolleri tek bir test isletmesinde (cccccccc-...-000000000001).

begin;

-- Oturumda önceden kalmış bir kullanıcı kimliği (SQL Editor rol taklidi
-- veya oturum düzeyinde request.jwt.claim.sub / request.jwt.claims)
-- audit trigger'ını "Not authorized to log an audit event" hatasıyla
-- durdurur. Kurulum kullanıcı oturumu olmadan çalışmalı.
reset role;
select set_config('request.jwt.claim.sub', '', true),
       set_config('request.jwt.claim.role', '', true),
       set_config('request.jwt.claims', '', true);

-- Auth kullanicilarinin gercekten var oldugunu dogrula.
do $$
declare
  v_missing_count integer;
begin
  select count(*)
    into v_missing_count
  from (
    values
      ('eecceeb6-504e-4a75-813b-99f19b61841b'::uuid),
      ('7d4ec330-d7e7-4d18-b394-9b1b26f68b9f'::uuid),
      ('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb'::uuid),
      ('c0d2e232-69a0-48f3-be90-aac2f3957034'::uuid),
      ('a96dbfd3-8265-4840-a47a-9dbde237269e'::uuid)
  ) as expected(id)
  left join auth.users u on u.id = expected.id
  where u.id is null;

  if v_missing_count > 0 then
    raise exception '% test kullanicisi auth.users tablosunda bulunamadi', v_missing_count;
  end if;
end;
$$;

-- Trigger herhangi bir nedenle profil olusturmadiysa eksik profilleri tamamla.
insert into public.profiles (id, full_name, email)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'full_name', split_part(u.email, '@', 1)),
  u.email
from auth.users u
where u.id in (
  'eecceeb6-504e-4a75-813b-99f19b61841b',
  '7d4ec330-d7e7-4d18-b394-9b1b26f68b9f',
  'a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb',
  'c0d2e232-69a0-48f3-be90-aac2f3957034',
  'a96dbfd3-8265-4840-a47a-9dbde237269e'
)
on conflict (id) do update
set email = excluded.email;

-- Platform super admin: yalnizca eecceeb6. Diger test kullanicilari
-- platform yoneticisi olmamali (yoksa isletme ekranlari yerine her seyi gorurler).
insert into public.platform_admins (user_id)
values ('eecceeb6-504e-4a75-813b-99f19b61841b')
on conflict (user_id) do nothing;

delete from public.platform_admins
where user_id in (
  '7d4ec330-d7e7-4d18-b394-9b1b26f68b9f',
  'a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb',
  'c0d2e232-69a0-48f3-be90-aac2f3957034',
  'a96dbfd3-8265-4840-a47a-9dbde237269e'
);

-- Test isletmesi. Sabit UUID sayesinde script tekrar calistirilabilir.
-- Ultra Super plan + ACTIVE: tum ozellikler (QR menu dahil) test edilebilir,
-- deneme suresi dolmaz.
insert into public.businesses (
  id,
  name,
  business_type,
  subscription_status,
  plan_id,
  active
)
values (
  'cccccccc-0000-0000-0000-000000000001',
  'MK Adisyon Test Isletmesi',
  'RESTAURANT',
  'ACTIVE',
  (select id from public.plans where code = 'ultra_super'),
  true
)
on conflict (id) do update
set
  subscription_status = 'ACTIVE',
  plan_id = coalesce(excluded.plan_id, public.businesses.plan_id),
  active = true;

-- Mobil uygulama ilk aktif uyelige gore ekran actigi icin test
-- kullanicilarinin baska isletmelerdeki aktif uyelikleri pasife alinir
-- (silinmez). Super admin'in hic aktif isletme uyeligi olmaz.
update public.business_memberships
set active = false
where active
  and user_id in (
    'eecceeb6-504e-4a75-813b-99f19b61841b',
    '7d4ec330-d7e7-4d18-b394-9b1b26f68b9f',
    'a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb',
    'c0d2e232-69a0-48f3-be90-aac2f3957034',
    'a96dbfd3-8265-4840-a47a-9dbde237269e'
  )
  and (
    business_id <> 'cccccccc-0000-0000-0000-000000000001'
    or user_id = 'eecceeb6-504e-4a75-813b-99f19b61841b'
  );

-- Isletme rolleri. Once rolleri bir kez pasif hale getirip sonra
-- aktiflestirmek, rol takasi sirasinda plan limit trigger'inin ara
-- durumda yanlis sayim yapmasini onler.
update public.business_memberships
set active = false
where business_id = 'cccccccc-0000-0000-0000-000000000001'
  and user_id in (
    '7d4ec330-d7e7-4d18-b394-9b1b26f68b9f',
    'a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb',
    'c0d2e232-69a0-48f3-be90-aac2f3957034',
    'a96dbfd3-8265-4840-a47a-9dbde237269e'
  );

insert into public.business_memberships (user_id, business_id, role, active)
values
  ('7d4ec330-d7e7-4d18-b394-9b1b26f68b9f', 'cccccccc-0000-0000-0000-000000000001', 'BUSINESS_ADMIN', true),
  ('c0d2e232-69a0-48f3-be90-aac2f3957034', 'cccccccc-0000-0000-0000-000000000001', 'CASHIER', true),
  ('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb', 'cccccccc-0000-0000-0000-000000000001', 'KITCHEN', true),
  ('a96dbfd3-8265-4840-a47a-9dbde237269e', 'cccccccc-0000-0000-0000-000000000001', 'WAITER', true)
on conflict (user_id, business_id) do update
set
  role = excluded.role,
  active = true;

commit;

-- Kurulum sonucu: 5 satir; her kullanici icin tek rol ve aktif uyelik.
select
  p.email,
  case
    when pa.user_id is not null then 'PLATFORM_SUPER_ADMIN'
    else bm.role
  end as role,
  b.name as business_name
from public.profiles p
left join public.platform_admins pa on pa.user_id = p.id
left join public.business_memberships bm on bm.user_id = p.id and bm.active
left join public.businesses b on b.id = bm.business_id
where p.id in (
  'eecceeb6-504e-4a75-813b-99f19b61841b',
  '7d4ec330-d7e7-4d18-b394-9b1b26f68b9f',
  'a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb',
  'c0d2e232-69a0-48f3-be90-aac2f3957034',
  'a96dbfd3-8265-4840-a47a-9dbde237269e'
)
order by role, p.email;
