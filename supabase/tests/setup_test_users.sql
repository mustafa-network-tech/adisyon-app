-- MK Adisyon kalici test kullanicisi kurulumu.
-- Bu dosya migration degildir. Yalnizca test/staging ortaminda,
-- Supabase SQL Editor uzerinden postgres yetkisiyle calistirin.

begin;

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

-- admin_a: platform super admin.
insert into public.platform_admins (user_id)
values ('eecceeb6-504e-4a75-813b-99f19b61841b')
on conflict (user_id) do nothing;

-- Test isletmesi. Sabit UUID sayesinde script tekrar calistirilabilir.
insert into public.businesses (
  id,
  name,
  business_type,
  subscription_status,
  active
)
values (
  'cccccccc-0000-0000-0000-000000000001',
  'MK Adisyon Test Isletmesi',
  'RESTAURANT',
  'ACTIVE',
  true
)
on conflict (id) do nothing;

-- Isletme rolleri:
-- admin_b = BUSINESS_ADMIN
-- waiter_a = WAITER
-- kitchen_a = KITCHEN
-- cashier_a = CASHIER
insert into public.business_memberships (user_id, business_id, role, active)
values
  ('a96dbfd3-8265-4840-a47a-9dbde237269e', 'cccccccc-0000-0000-0000-000000000001', 'BUSINESS_ADMIN', true),
  ('7d4ec330-d7e7-4d18-b394-9b1b26f68b9f', 'cccccccc-0000-0000-0000-000000000001', 'WAITER', true),
  ('a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb', 'cccccccc-0000-0000-0000-000000000001', 'KITCHEN', true),
  ('c0d2e232-69a0-48f3-be90-aac2f3957034', 'cccccccc-0000-0000-0000-000000000001', 'CASHIER', true)
on conflict (user_id, business_id) do update
set
  role = excluded.role,
  active = true;

commit;

-- Kurulum sonucu: bu sorgu 5 satir dondurmelidir.
select
  p.email,
  case
    when pa.user_id is not null then 'PLATFORM_SUPER_ADMIN'
    else bm.role
  end as role,
  b.name as business_name,
  coalesce(bm.active, true) as active
from public.profiles p
left join public.platform_admins pa on pa.user_id = p.id
left join public.business_memberships bm on bm.user_id = p.id
left join public.businesses b on b.id = bm.business_id
where p.id in (
  'eecceeb6-504e-4a75-813b-99f19b61841b',
  '7d4ec330-d7e7-4d18-b394-9b1b26f68b9f',
  'a0ceeb8a-0abf-4548-bc80-f9b8ac7970fb',
  'c0d2e232-69a0-48f3-be90-aac2f3957034',
  'a96dbfd3-8265-4840-a47a-9dbde237269e'
)
order by role, p.email;
