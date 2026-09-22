# MK Adisyon — Mimari Doküman

Bu doküman, projenin master prompt'unda (bölüm 37) istenen 16 maddelik
mimari planın kalıcı referansıdır. Kod değiştikçe bu dosya da güncellenmelidir.

## 1. Genel Mimari

Tek Supabase (PostgreSQL) backend, iki istemci: Next.js (web) ve Flutter
(Android). İstemciler asla birbirine veya ayrı bir API katmanına bağımlı
değildir; ikisi de doğrudan Supabase Auth + PostgREST/RPC + Realtime
kullanır. İş kuralları mümkün olduğunca veritabanı seviyesinde (RLS,
constraints, trigger, SECURITY DEFINER fonksiyonlar) uygulanır ki hangi
istemciden gelirse gelsin aynı garanti geçerli olsun. Next.js tarafında
gerektiğinde Route Handlers / Server Actions "ince" bir orkestrasyon
katmanı olarak kullanılır (örn. onboarding sırasında birden fazla tabloyu
tek transaction'da güncellemek), ama service role key yalnızca sunucu
tarafında (Next.js server runtime, asla client bundle) kullanılır.

## 2. Monorepo / Klasör Yapısı

```
mk-adisyon-app/
  apps/
    web/                  # Next.js (App Router) - FAZ 2+
    mobile/                # Flutter - FAZ 4+
  supabase/
    migrations/            # sıralı SQL migration dosyaları (tek doğruluk kaynağı)
    config.toml             # supabase CLI local dev config (FAZ ilerledikçe eklenecek)
  docs/
    ARCHITECTURE.md         # bu dosya
  README.md
```

`apps/web` ve `apps/mobile` FAZ 2 ve FAZ 4'te gerçek proje iskeletleriyle
doldurulacak. Şimdilik `supabase/` klasörü aktif çalışma alanı.

## 3. Supabase Database Schema

Tablolar ve ilişkiler (bkz. `supabase/migrations/`):

- `profiles` (1-1 `auth.users`) — ad, telefon
- `platform_admins` (user_id PK) — PLATFORM_SUPER_ADMIN üyeliği, business'tan bağımsız
- `plans` — dinamik plan/limit tanımları (hard-code yok)
- `businesses` — tenant kökü; trial/subscription alanları burada
- `subscriptions` — business'ın plan geçmişi/güncel ataması
- `business_applications` — public başvuru formu (PENDING/APPROVED/REJECTED)
- `business_memberships` — user ↔ business ↔ role (BUSINESS_ADMIN/CASHIER/WAITER/KITCHEN)
- `areas` — salon/bahçe/teras vb.
- `restaurant_tables` — area'ya bağlı masalar
- `categories`, `products` — menü
- `orders` — masa "hesabı" (OPEN/CLOSED/CANCELLED)
- `order_items` — sipariş kalemleri, fiyat snapshot + mutfak durumu (NEW/PREPARING/READY/SERVED/VOID)
- `payments` — parçalı ödemeler (CASH/CARD/OTHER), VOID ile iptal (fiziksel silme yok)
- `support_requests`, `custom_software_requests`
- `audit_logs` — immutable, yalnızca INSERT (trigger/RPC üzerinden)

Tasarım kararları:
- Her tenant-scoped tabloda doğrudan `business_id` kolonu var (area/table
  üzerinden dolaylı join yerine RLS'i basit ve hızlı tutmak için
  denormalize edilmiş, trigger ile tutarlılığı korunan bir alan).
  `order_items` ve `payments` da kendi `business_id`'sini taşır.
- Multi-branch (bölüm 22) için şimdilik ayrı `branches` tablosu
  AÇILMADI — gereksiz karmaşıklık. `business_id` her yerde zorunlu FK
  olduğu için ileride `branches` tablosu eklenip `branch_id` nullable
  kolon olarak tabloculara eklenmesi mevcut şemayı bozmaz (additive migration).
- Para alanları `numeric(10,2)`. Zaman alanları `timestamptz`.
- Kritik finansal kayıtlar (`order_items`, `payments`) fiziksel DELETE
  desteklemez; RLS'te DELETE policy tanımlı değildir. İptal `status =
  'VOID'` + `voided_by`/`voided_at`/`void_reason` ile yönetilir.

## 4. Auth Mimarisi

Supabase Auth (email/password başlangıç için yeterli; ileride telefon/OTP
eklenebilir). `auth.users` INSERT'inde bir trigger otomatik olarak
`profiles` satırı oluşturur (`handle_new_user`). Uygulamalar asla
`auth.users`'a doğrudan yazmaz.

Session yönetimi tamamen Supabase SDK'larına (supabase-js / supabase-flutter)
devredilir (refresh token rotation dahil). Web tarafında Next.js
middleware ile server-side session senkronizasyonu (cookies) FAZ 2'de
kurulacak.

## 5. Membership Mimarisi

Bir kullanıcının birden fazla business'a üyeliği olabilir (bölüm 5,
gelecek ihtiyaç). `business_memberships` tablosu `(user_id, business_id)`
üzerinde UNIQUE'dir — bir kullanıcı bir business'ta tek role sahiptir,
ama farklı business'larda farklı rollere/üyeliklere sahip olabilir.
PLATFORM_SUPER_ADMIN business'tan bağımsız olduğu için ayrı
`platform_admins` tablosunda tutulur; bu tabloya client'tan INSERT/UPDATE/DELETE
policy'si YOKTUR — yalnızca service role (Super Admin bootstrap) ile
yönetilir, böylece bir kullanıcı kendi kendine platform admin yapamaz.

Aktif rol seçimi (kullanıcı birden fazla business'a üyeyse) istemci
state'inde tutulur ama bu yalnızca UX içindir; her sorgu/mutasyon RLS
tarafından bağımsızca doğrulanır — istemcinin "hangi business'tayım"
dediğine güvenilmez.

## 6. RLS Stratejisi

Tüm tenant tablolarında RLS `ENABLED` + `FORCE`. İki SECURITY DEFINER
yardımcı fonksiyon (`search_path` sabitlenmiş, `public` şemasında):

- `is_platform_admin() returns boolean` — `platform_admins`'te `auth.uid()` var mı
- `has_business_role(p_business_id uuid, p_roles text[]) returns boolean`
  — `business_memberships`'te aktif, ilgili business + role eşleşmesi var mı

Bu fonksiyonlar RLS'i bypass ederek (SECURITY DEFINER) kendi
tablolarını okur, böylece policy'lerde sonsuz döngü / performans sorunu
oluşmaz. Policy şablonu:

- SELECT: `is_platform_admin() OR has_business_role(business_id, ARRAY[...ilgili roller...])`
- INSERT/UPDATE: role bazlı (örn. `products` için sadece `BUSINESS_ADMIN`;
  `order_items` INSERT için `WAITER, BUSINESS_ADMIN, CASHIER`; `payments`
  INSERT için `CASHIER, BUSINESS_ADMIN`)
- Hassas veri (payments, ciro) WAITER/KITCHEN policy'lerine hiç dahil
  edilmez — "UI'da gizleme" değil, satır düzeyinde erişim yok.
- `audit_logs`: SELECT yalnızca `BUSINESS_ADMIN`(kendi business'ı) veya
  platform admin; INSERT yalnızca trigger/RPC (SECURITY DEFINER) üzerinden;
  UPDATE/DELETE policy'si yok (immutable).

Client'tan gelen `business_id` asla güvenilir kabul edilmez: her policy
`auth.uid()` üzerinden `business_memberships`'i sorgular.

## 7. Realtime Stratejisi

`orders` ve `order_items` tabloları Realtime publication'a dahil edilir.
İstemciler yalnızca kendi `business_id`'lerine ait satırlara subscribe
olabilir — bu RLS ile garanti edilir (Realtime de RLS'e tabidir).
Flutter mutfak/garson ekranları `order_items` üzerinde
`business_id=eq.<id>` filtresiyle tek bir subscription açar (masa/kategori
bazında ayrı ayrı subscription açılmaz). Bağlantı kopması durumunda
SDK'nın otomatik reconnect'i kullanılır + reconnect sonrası bir kerelik
REST fetch ile state resync yapılır (kaçırılan event'leri telafi için).

## 8. Web Mimarisi (FAZ 2+ detay)

Next.js App Router, route group'larla rol bazlı ayrım:
`(public)/apply`, `(super-admin)/...`, `(business)/...` (admin/kasa/mutfak
alt route'ları). Server Components veri okuma için, Server
Actions/Route Handlers mutasyon + service-role gerektiren onboarding
işlemleri için. Tailwind ile 3 ayrı görsel dil (POS/kasa, SaaS dashboard,
platform yönetim) ama tek design token seti.

## 9. Flutter Mimarisi (FAZ 4+ detay)

Feature-first klasörleme (`features/auth`, `features/waiter`,
`features/kitchen`, `features/cashier`, `features/admin`), role bazlı
routing guard (giriş sonrası membership+role'e göre yönlendirme).
Supabase Flutter SDK, Riverpod (veya benzeri) ile state management.
Network/connectivity durumu global bir provider ile izlenir.

## 10. Order Lifecycle

```
Masa AVAILABLE
  → Garson masa açar → orders(status=OPEN) oluşur, table.status=OCCUPIED
  → order_items eklenir (status=NEW)
  → Mutfak: NEW → PREPARING → READY → SERVED
  → Garson ek ürün ekleyebilir (yeni order_items, aynı order)
  → Garson/Kasa "hesap istendi" işaretler → table.status=CHECK_REQUESTED
  → Kasa ödeme alır (bkz. Payment Lifecycle)
  → Tüm tutar karşılandığında orders.status=CLOSED, table.status=AVAILABLE
İptal: order_items.status=VOID (audit_log ile)
```

## 11. Payment Lifecycle

```
orders(OPEN, total = Σ order_items(status != VOID))
  → payments INSERT (CASH/CARD/OTHER, amount) — birden fazla kayıt (split)
  → Σ payments(status=COMPLETED) >= order total olunca order CLOSED
  → Hatalı ödeme: payments.status=VOID (silme yok), audit_log
```
Idempotency: kritik mutasyonlarda (order açma, ödeme ekleme) istemciden
üretilen bir `client_request_id` ile duplicate submission engellenecek
(FAZ 7'de `payments`/`orders`'a unique constraint + RPC olarak detaylandırılacak).

## 12. Trial / Subscription Yaklaşımı

`businesses.subscription_status` (TRIAL/ACTIVE/EXPIRED/SUSPENDED/CANCELLED)
tek doğruluk kaynağıdır; `subscriptions` tablosu plan atama geçmişini
tutar. Süre bitiminde veri SİLİNMEZ; yalnızca yeni operasyon
oluşturma (yeni sipariş açma vb.) sunucu tarafında (RLS + kontrol
fonksiyonu) engellenir. Bu kontrol FAZ 9'da `has_business_role` ile
birlikte `business_is_operational(business_id)` fonksiyonu eklenerek
yapılacak — FAZ 1'de yalnızca alanlar/durumlar şemaya kondu.

## 13. Güvenlik Riskleri ve Önlemler

- **Cross-tenant veri sızıntısı** → RLS + FORCE ROW LEVEL SECURITY, client
  `business_id`'sine güvenilmez.
- **Rol yükseltme (self platform-admin)** → `platform_admins` client
  yazamaz; `business_memberships` INSERT/UPDATE yalnızca `BUSINESS_ADMIN`
  kendi business'ında, `role` alanı `PLATFORM_SUPER_ADMIN` değerini kabul
  etmez (CHECK constraint zaten bu değeri içermiyor).
- **Service role sızıntısı** → yalnızca Next.js server-side env; Flutter/
  browser bundle'a asla konmaz.
- **Finansal veri tutarsızlığı** → fiyat snapshot, immutable payments/
  order_items (VOID pattern), audit_logs.
- **Audit log manipülasyonu** → UPDATE/DELETE policy yok, INSERT yalnızca
  SECURITY DEFINER fonksiyon üzerinden.
- **Duplicate order/payment (offline/çift tıklama)** → idempotency key
  (FAZ 7).

## 14. Geliştirme Fazları

Bkz. master prompt bölüm 36 — aynen uygulanacak (FAZ 1 → FAZ 12).

## 15. İlk Uygulanacak Görevler (FAZ 1)

1. Monorepo iskeleti (`apps/web`, `apps/mobile`, `supabase/`) — tamam
2. SQL migrations: profiles, platform_admins, plans, businesses,
   business_memberships, business_applications, subscriptions, areas,
   restaurant_tables, categories, products, orders, order_items,
   payments, support_requests, custom_software_requests, audit_logs
3. Her tabloda RLS + policy'ler
4. Yardımcı fonksiyonlar (`is_platform_admin`, `has_business_role`)
5. `updated_at` trigger'ı (generic)
6. `handle_new_user` trigger'ı (auth.users → profiles)

## 16. Notlar

**Faz 3 güncellemeleri (`20260922000018_profiles_email_and_business_guard.sql`):**
`profiles`'a `email` kolonu eklendi (business admin'in servis rolüne
ihtiyaç duymadan kendi personel listesini görebilmesi için,
`auth.users.email`'den denormalize edilir). Ayrıca `businesses` tablosuna
bir trigger eklendi: `BUSINESS_ADMIN` kendi işletmesini güncelleyebilir
ama `subscription_status`/`plan_id`/`trial_started_at`/`trial_ends_at`/
`active` alanlarını **değiştiremez** — bunlar yalnızca platform admin
tarafından değiştirilebilir (Faz 1'de bu kısıtlama yalnızca "uygulama
katmanında" olacağı notuyla bırakılmıştı; Faz 3'te işletme ayarları
ekranı gerçek yazma erişimi kullandığı için veritabanı seviyesine
taşındı).

**Faz 5 güncellemeleri (`20260922000019_order_lifecycle_and_waiter_guards.sql`):**
`restaurant_tables.status` artık tamamen `orders`'tan türetiliyor (bir
trigger ile) — masa açıldığında OCCUPIED, hesap istendiğinde
CHECK_REQUESTED, sipariş kapandığında/iptal olduğunda AVAILABLE; client
artık bunu ayrıca güncellemek zorunda değil ve unutamaz. Aynı masada
aynı anda birden fazla OPEN sipariş açılmasını engelleyen bir partial
unique index eklendi (iki garsonun aynı masayı eş zamanlı açması gibi
bir yarış durumuna karşı). `order_items` VOID akışı sıkılaştırıldı:
`voided_by`/`voided_at` artık her zaman sunucuda `auth.uid()`/`now()`'dan
alınıyor (client'ın başka birinin id'sini yazabilmesi kapatıldı),
`void_reason` zorunlu hale getirildi, ve WAITER yalnızca hâlâ `NEW`
durumundaki bir kalemi iptal edebiliyor (mutfak hazırlamaya başladıktan
sonra iptal CASHIER/BUSINESS_ADMIN yetkisi gerektiriyor); KITCHEN hiç
VOID yapamıyor. `restaurant_tables` realtime publication'a eklendi
(garson masa ızgarasının canlı güncellenmesi için).

**Faz 6 notları:** Mutfak ekranı (Flutter + Web) hem `order_items` hem
`orders` realtime akışlarını dinliyor ve masa adlarını (`restaurant_tables`)
ayrı bir sorguyla alıp client tarafında birleştiriyor — `.stream()`/
`postgres_changes` join desteklemediği için (Faz 1'de zaten bu üç tablo
realtime publication'a eklenmişti). Mutfak ekranı bilinçli olarak fiyat/
toplam göstermiyor (section 15: "Mutfak finansal bilgi görmemeli") —
bu, RLS'te ayrı bir kısıtlama değil, ekran tasarımı kararı: `order_items`
satırı zaten fiyat kolonu taşıyor (sipariş kalemi olarak gerekli), ama
KITCHEN rolünün arayüzü onu hiç render etmiyor. KITCHEN, `order_items`
üzerinde NEW→PREPARING→READY→SERVED geçişlerini serbestçe yapabiliyor
(DB'de sıra zorlaması yok, arayüz doğrusal ilerlemeyi yönlendiriyor);
VOID hâlâ Faz 5'teki trigger ile KITCHEN'a tamamen kapalı.

**Faz 7 notları (`20260922000020_payment_and_order_close_guards.sql`):**
Sipariş kapatma/iptal artık veritabanı seviyesinde korunuyor: bir siparişi
yalnızca CASHIER/BUSINESS_ADMIN kapatabilir/iptal edebilir (WAITER
`status` kolonunu değiştiremez, yalnızca `check_requested`'i
değiştirebilir); **tam ödenmeden** bir sipariş kapatılamaz; **hiç
ödemesi tamamlanmamış** bir sipariş dışında bir sipariş iptal edilemez.
`payments.received_by` artık her zaman sunucuda `auth.uid()`'den
alınıyor (Faz 1'de client'tan geliyordu — bir kasiyer başka bir
personele ödeme "yazdırabilirdi", kapatıldı). `payments` VOID akışı
`order_items` ile aynı desene kavuştu: `voided_by`/`voided_at` sunucuda,
`void_reason` zorunlu, yalnızca sipariş hâlâ OPEN iken iptal edilebilir
(kapanmış bir siparişin ödemesini düzeltmek gerçek bir "yeniden açma"
akışı gerektirir — bilinçli olarak bu faza dahil edilmedi, manuel/admin
müdahalesi olarak kalıyor).

**Faz 8 notları (`20260922000021_reporting_functions.sql`):** Raporlar
(`get_revenue_summary`, `get_top_products`) düz SQL fonksiyonları olarak
yazıldı — SECURITY DEFINER **değil**, çağıranın kendi RLS'i altında
çalışıyorlar. Bu bilinçli bir tercih: fonksiyon `p_business_id`
parametresini client'tan alsa bile, altındaki `payments`/`order_items`
sorguları hâlâ `is_business_member(row.business_id)` politikasına tabi;
biri başka bir işletmenin id'sini geçse bile sıfır satır döner, gerçek
veri sızmaz — fonksiyonun içine ayrıca bir yetki kontrolü eklemeye
gerek kalmadı. `/raporlar` web'de yeni bir rota; hem BUSINESS_ADMIN hem
CASHIER'a açık (`getReportsContext`, ortak `getMembershipContext`
artık tek bir rol yerine rol listesi de kabul ediyor). Flutter tarafı
bu fazda yok — master prompt'un faz listesinde yalnızca bu fazda
"Flutter" ön eki geçmiyor (Faz 5/6/7'nin aksine), rapor ekranları
doğası gereği masaüstü/web odaklı.

**Faz 9 notları (`20260922000022_trial_and_plan_limits.sql`):**
`business_is_operational(business_id)` fonksiyonu bir işletmenin yeni
sipariş açıp açamayacağını belirliyor (ACTIVE, veya TRIAL +
`trial_ends_at` henüz geçmemiş). Bu kontrol yalnızca `orders` INSERT'inde
uygulanıyor — **halihazırda açık bir hesabı kapatmak/ödemek asla
engellenmiyor**; deneme süresi servis ortasında dolsa bile müşteri
mağdur olmuyor. `max_areas`/`max_tables`/`max_waiters`/`max_users` plan
limitleri sırasıyla `areas`/`restaurant_tables`/`business_memberships`
INSERT'lerinde kontrol ediliyor; işletmeye plan atanmamışsa veya bir
limit `null` ise sınırsız kabul ediliyor. Her iki kontrol de Postgres
`RAISE EXCEPTION` mesajına `PLAN_LIMIT_EXCEEDED`/
`TRIAL_OR_SUBSCRIPTION_INACTIVE` öneki koyuyor; web (`lib/supabase/errors.ts`)
ve Flutter (`core/utils/errors.dart`) tarafında bu önek yakalanıp
anlaşılır Türkçe mesaja çevriliyor.

Süper Admin artık `/super-admin/planlar`'dan plan oluşturabiliyor/
düzenleyebiliyor ve işletme detay sayfasından (`/super-admin/isletmeler/[id]`)
bir işletmeye plan atayabiliyor — Faz 1'den beri var olan `plans`
tablosunun ilk gerçek yönetim arayüzü. `/isletme` paneline bir abonelik
durumu banner'ı eklendi (deneme gün sayacı, askıya alma/süre dolma
uyarısı) — section 8'in "kullanıcıya anlaşılır abonelik ekranı göster"
maddesi.

**Faz 10 notları (`20260922000023_qr_menu.sql`):** QR Menü public
sayfası (`/menu/[businessId]`) `categories`/`products`/`businesses`
tablolarına doğrudan anon erişim **açmıyor** — RLS satır seviyesinde
olduğu için bu, `businesses`'in e-posta/telefon/deneme tarihi gibi
hassas kolonlarını da sızdırırdı. Bunun yerine iki SECURITY DEFINER
fonksiyon (`get_qr_menu_business`, `get_qr_menu_items`) yalnızca güvenli
bir projeksiyon döndürüyor, ve yalnızca işletmenin planında
`qr_menu_enabled = true` ise satır dönüyor — sıfır satır, "bulunamadı"
ile "QR menü kapalı" arasında ayrım yapılmasını engelliyor (bir
saldırganın hangi işletmelerin var olduğunu bu yoldan keşfetmesini
zorlaştırıyor). QR kod görseli `/isletme/qr-menu`'de sunucu tarafında
`qrcode` npm paketiyle SVG olarak üretiliyor — üçüncü taraf bir QR
servisine istek atılmıyor. Destek (`support_requests`) ve özel yazılım
(`custom_software_requests`) talepleri için ayrı bir migration
gerekmedi — RLS politikaları zaten Faz 1'de doğru kurulmuştu, yalnızca
arayüz eksikti (`/isletme/destek`, `/super-admin/destek`).

**Faz 11 notları:** Section 29'un RLS penetrasyon senaryolarının
sistematik incelemesi, bulunan 3 gerçek boşluk
(`20260922000024_security_review_hardening.sql`), audit log kapsam
tablosu ve bilinçli olarak ertelenen riskler için ayrı bir doküman var:
[`docs/SECURITY_REVIEW.md`](SECURITY_REVIEW.md). Gerçek bir Supabase
projesinde çalıştırılabilir bir doğrulama script'i de eklendi:
[`supabase/tests/rls_penetration_tests.sql`](../supabase/tests/rls_penetration_tests.sql)
(tamamen bir transaction içinde çalışır, `ROLLBACK` ile biter).
`/super-admin/audit` ve `/isletme/audit` ile audit_logs artık
görüntülenebiliyor (Faz 1'den beri veritabanında vardı ama arayüzü
yoktu).

**Faz 12 notları (self-service + Google Play altyapısı +
audit RPC sertleştirme):** Master prompt'un mimari revizyonu üç ana
değişiklik getirdi:

1. **İşletmeler artık Super Admin onayıyla açılmıyor.** `/basvuru`
   (public başvuru formu) ve `business_applications` üzerinden manuel
   onay akışı kaldırıldı (`business_applications_insert_public` policy'si
   drop edildi -- tablo ve geçmiş kayıtlar silinmedi, `/super-admin/basvurular`
   salt-okunur bir arşive dönüştü). Yerine `/kayit`: kullanıcı kendi
   hesabını ve işletmesini tek adımda oluşturuyor, `public.create_own_business`
   (SECURITY DEFINER) trial alanlarını (subscription_status='TRIAL',
   trial_ends_at=+7 gün, plan_id=null=sınırsız) tamamen sunucuda hesaplıyor,
   client'tan hiçbir trial/durum alanı kabul etmiyor
   (`20260922000025_self_service_business_signup.sql`).
2. **Google Play abonelik alt yapısı** (`20260922000026_google_play_subscriptions.sql`):
   `plans`'a Play product/base-plan eşleştirme kolonları, `google_play_purchases`
   tablosu (purchase_token yalnızca platform admin'e SELECT edilebilir,
   client insert/update policy'si yok), business-scoped güvenli projeksiyon
   (`get_own_business_subscription`, token'ı hiç döndürmez), ve doğrulama
   giriş noktası `apply_google_play_verification_result` (henüz hiçbir role
   grant edilmedi -- gerçek Google Play Developer API entegrasyonu bu
   ortamda credential olmadığı için yapılmadı, bkz. bölüm 16 sonu).
   `subscription_status`/`subscriptions.status` check constraint'lerine
   `GRACE_PERIOD` eklendi.
3. **Audit RPC sertleştirme** (`20260922000027_audit_rpc_hardening.sql`):
   `log_audit_event`'in `authenticated`'e execute grant'i kaldırıldı --
   önceden herhangi bir WAITER/CASHIER kendi business'ı için tamamen
   uydurma `action`/`entity`/`metadata` içerikli sahte denetim kaydı
   yazabiliyordu (yalnızca `is_business_member` kontrolü vardı, loglanan
   olayın gerçekten olup olmadığını doğrulayan hiçbir mekanizma yoktu).
   Artık hassas olaylar (ödeme/kalem/sipariş iptali, personel
   davet/rol/aktiflik değişikliği, işletme askıya alma/aktive etme/plan
   atama/trial uzatma, başvuru onay/red) doğrudan ilgili tablonun
   trigger'ından, gerçek OLD/NEW satır farkından otomatik loglanıyor --
   client artık hiçbir audit kaydı yazamıyor.

Flutter tarafında PLATFORM_SUPER_ADMIN'e ait hiçbir rol/route/ekran yok
(kaldırıldı: `AppRole.platformAdmin`, `/platform-yonetimi`,
`PlatformAdminInfoScreen`) -- bu rol yalnızca web Super Admin panelinde
var. Backend `platform_admins` tablosu ve `is_platform_admin()` RLS
yardımcı fonksiyonu dokunulmadı (hâlâ gerekli).

Bu ortamda Supabase CLI kurulu değil (`supabase` komutu bulunamadı).
Migration'ları uygulamak için:

```
npm install -g supabase
supabase login
supabase link --project-ref <PROJECT_REF>
supabase db push
```

veya Supabase Dashboard → SQL Editor üzerinden `supabase/migrations/`
altındaki dosyaları sırayla çalıştırabilirsiniz.
