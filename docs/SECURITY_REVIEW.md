# Güvenlik İncelemesi — Faz 11

Bu doküman, master prompt'un 29/30/34/35. bölümlerinde istenen RLS
penetrasyon senaryolarının, audit log kapsamının ve genel güvenlik
duruşunun Faz 11'de yapılan sistematik incelemesini kayıt altına alır.

## Yöntem ve sınırlama

Bu ortamda canlı bir Supabase projesi yok, yalnızca migration
dosyalarının kendisi var. Bu yüzden inceleme iki parçadan oluşuyor:

1. **Statik kod incelemesi** (bu dokümanın asıl içeriği) — her migration
   dosyasındaki her `create policy` ve her trigger fonksiyonu tek tek
   okunup, aşağıdaki senaryolara karşı elle doğrulandı.
2. **Çalıştırılabilir test** — [`supabase/tests/rls_penetration_tests.sql`](../supabase/tests/rls_penetration_tests.sql)
   dosyası, bu senaryoları gerçek bir Supabase projesinde otomatik
   PASS/FAIL olarak raporlayan bir script. **Bu script bu ortamda
   çalıştırılmadı** — gerçek bir projede çalıştırıp sonucu doğrulamanızı
   öneririz. Tamamen bir transaction içinde çalışır ve `ROLLBACK` ile
   biter, hiçbir kalıcı veri yazmaz.

## Section 29 senaryoları — sonuç

| # | Senaryo | Sonuç | Nerede uygulanıyor |
|---|---|---|---|
| 1 | Business A → Business B masalarını görebiliyor mu? | **HAYIR** | `restaurant_tables_select_member`: `is_business_member(business_id)` |
| 2 | Business A → Business B siparişini okuyabiliyor mu? | **HAYIR** | `orders_select_member`: aynı desen |
| 3 | Business A → Business B verisini update edebiliyor mu? | **HAYIR** | Her yazma politikası `has_business_role(business_id, ...)` ile hedef satırın gerçek `business_id`'sini kontrol ediyor; `WITH CHECK` yeni değeri de aynı şekilde doğruluyor |
| 4 | WAITER → ciroyu (payments) okuyabiliyor mu? | **HAYIR** | `payments_select_cashier`: rol listesinde WAITER yok |
| 5 | KITCHEN → payments görebiliyor mu? | **HAYIR** | Aynı politika, KITCHEN da yok |
| 6 | Normal BUSINESS_ADMIN → PLATFORM_SUPER_ADMIN işlemi yapabiliyor mu? | **HAYIR** | `platform_admins`'e hiç client-facing yazma politikası yok; `business_memberships.role` CHECK constraint'i `PLATFORM_SUPER_ADMIN` değerini hiç kabul etmiyor |
| 7 | CASHIER → başka işletmenin ödemesini görebiliyor mu? | **HAYIR** | `payments_select_cashier`, hedef satırın `business_id`'sine göre filtreliyor; client'ın sorgu parametreleri bunu değiştiremiyor |
| 8 | Client `business_id` değiştirerek başka tenant'a geçebiliyor mu? | **HAYIR** | Her INSERT'te `business_id` ya bir üst kayıttan (`order_id`→`orders.business_id` gibi) sunucuda türetiliyor ya da bir trigger ile gerçek ilişkiye karşı doğrulanıyor (`check_order_table_business` vb.) |

Sekizinin de "HAYIR" (güvenli) çıkması bekleniyor. Yukarıdaki her satır,
`rls_penetration_tests.sql`'de ilgili numaralı senaryo olarak da var.

## Bu fazda bulunan ve düzeltilen 3 gerçek açık

Sistematik incelemede, önceki fazlarda gözden kaçmış üç gerçek boşluk
bulundu (hepsi `20260922000024_security_review_hardening.sql`'de
düzeltildi):

1. **`orders.opened_by` client tarafından sahtelenip değiştirilebiliyordu.**
   `voided_by`/`received_by` için Faz 5/7'de yapılan düzeltmenin aynısı
   eksikti. Artık INSERT'te her zaman `auth.uid()`'den zorla alınıyor,
   UPDATE'te `table_id` ile birlikte değiştirilemez.
2. **`business_memberships.user_id`/`business_id` UPDATE ile
   değiştirilebiliyordu.** Bir BUSINESS_ADMIN, kendi işletmesindeki
   mevcut bir üyelik satırının `user_id`'sini davet akışını hiç
   kullanmadan rastgele bir kullanıcıya çevirebilirdi (tenant sınırını
   aşmıyordu ama davet sürecini atlıyordu). Artık bu iki kolon
   oluşturulduktan sonra değiştirilemez.
3. **`support_requests.requester_id` client tarafından sahtelenip
   değiştirilebiliyordu.** Aynı sınıf sorun, aynı çözüm: her zaman
   `auth.uid()`'den alınıyor.

Bunların hiçbiri gerçek bir tenant sınırı ihlali değildi (hepsi bir
kullanıcının **kendi** işletmesi içinde kimlik sahteciliği yapabilmesiyle
sınırlıydı), ama section 30'un "kim yaptı" vurgusuyla doğrudan
çelişiyorlardı, o yüzden düzeltildi.

## Audit log kapsamı (section 30)

| Olay | Durum |
|---|---|
| İşletme onayı/reddi | ✅ Faz 2 |
| Suspend/reactivation | ✅ Faz 3 |
| Personel oluşturma/rol değiştirme | ✅ Faz 3 |
| Plan değişimi | ✅ Faz 9 |
| Sipariş iptali | ✅ Faz 11'de eklendi (`ORDER_CANCELLED`) |
| Ödeme iptali | ✅ Faz 11'de eklendi (`PAYMENT_VOIDED`) |
| Ürün kalemi iptali | ✅ Faz 11'de eklendi (`ORDER_ITEM_VOIDED`) — section 30'da açıkça listelenmemiş ama aynı kategoriden, tutarlılık için eklendi |

`audit_logs` tablosunun kendisi INSERT/UPDATE/DELETE için client'a hiç
açık değil (yalnızca `log_audit_event` SECURITY DEFINER RPC'si üzerinden
yazılıyor) — bu Faz 1'den beri değişmedi. Görüntüleme arayüzü Faz
11'de eklendi: `/super-admin/audit` (platform geneli) ve `/isletme/audit`
(kendi işletmesi, RLS ile otomatik sınırlı).

## Bilinçli olarak ele alınmayan / ertelenen riskler

Bunlar gözden kaçırılmadı — bilinçli kapsam kararları, burada açıkça
kayıtlı:

- **order_items durum geçiş sırası zorlanmıyor** (örn. KITCHEN olmayan
  biri NEW'den doğrudan SERVED'e atlayabilir). VOID hariç hiçbir
  geçişte rol bazlı sıra kontrolü yok. Düşük risk (tenant sınırını
  aşmıyor), kasıtlı olarak eklenmedi (Faz 6 notu).
- **İdempotency key yok** — aynı ödeme/sipariş isteğinin çift
  gönderimine (çift dokunma, offline retry) karşı bir koruma yok. Faz
  1'den beri açık, hâlâ açık. Üretime çıkmadan önce ele alınmalı.
- **İki işletmede de admin olan bir kullanıcı**, `areas`/`categories`/
  `products`/`restaurant_tables` satırlarını bu iki işletme arasında
  taşıyabilir (`business_id` güncellemesi her ikisinde de admin olduğu
  için RLS'i geçer). Gerçek bir tenant sınırı ihlali değil (her iki
  tarafta da yetkili), düşük öncelik.
- **Raporlar sunucu yerel saatine göre gün sınırı hesaplıyor** — işletme
  bazlı saat dilimi kolonu yok (Faz 8 notu).
- **QR menü** (`get_qr_menu_*`) bilerek `business.active` ve
  `plan.qr_menu_enabled` dışında bir kontrol yapmıyor —
  `subscription_status` (TRIAL/SUSPENDED vb.) menü görünürlüğünü
  etkilemiyor; salt-okunur bir menüyü göstermek operasyonel bir risk
  taşımıyor (Faz 10 notu).

## Faz 12: genel amaçlı audit RPC açığı (bağımsız/Codex denetim bulgusu)

Bağımsız bir güvenlik denetiminde, `log_audit_event`'in `authenticated`
rolüne `grant execute` edilmiş olması ve tek kontrolünün
`is_business_member(p_business_id)` olması işaretlendi: `action`,
`entity`, `entity_id`, `metadata` alanları tamamen client tarafından
belirleniyordu, hiçbir gerçek DB olayına bağlı değildi. Somut senaryo:
herhangi bir WAITER veya CASHIER (ikisi de `is_business_member`'ı geçer)
devtools'tan doğrudan
`supabase.rpc('log_audit_event', { p_business_id: <kendi işletmesi>,
p_action: 'HERHANGİ_BİR_ŞEY', p_entity: 'herhangi', p_entity_id: <hiç
kontrol edilmeyen, başka işletmeye bile ait olabilecek bir uuid>,
p_metadata: {...} })` çağırıp, arayüzde gerçek bir kayıttan ayırt
edilemeyen, hiç yaşanmamış bir olay için sahte denetim kaydı
yazabiliyordu. Bu, section 30'un "kim, ne zaman, ne yaptı" garantisini
doğrudan geçersiz kılıyordu.

**Düzeltme** (`20260922000027_audit_rpc_hardening.sql`):
`log_audit_event`'in `authenticated`'e execute grant'i tamamen
kaldırıldı -- client artık bu fonksiyonu hiç çağıramıyor. Önceden bu
RPC'yi ikinci, ayrı bir "güvenilir" çağrı olarak kullanan her hassas
olay (ödeme/sipariş kalemi/sipariş iptali, personel davet/rol/aktiflik
değişikliği, işletme askıya alma/aktive etme/plan atama/trial uzatma,
başvuru onay/red) artık ilgili tablonun trigger'ından otomatik
loglanıyor -- action/entity/metadata gerçek `OLD`/`NEW` satır farkından
türetiliyor, client'ın iddiasından değil. Trigger fonksiyonları
`SECURITY DEFINER` olduğu için `log_audit_event`'i owner yetkisiyle
çağırabiliyor (revoke yalnızca `authenticated`'i etkiliyor, fonksiyon
sahibini değil) -- bu yüzden sahte bir kayıt yazmak artık ilgili gerçek
state değişikliğini (ve ona ait yetkiyi) gerçekten yapmayı gerektiriyor.

## Performans

Faz 8'in rapor sorguları (`get_revenue_summary`, `get_top_products`,
geçmiş işlemler listesi) `business_id` + tarih aralığına göre filtreliyor.
Faz 11'de bu üç WHERE deseniyle eşleşen composite index'ler eklendi:
`idx_payments_business_created_at`, `idx_order_items_business_created_at`,
`idx_orders_business_closed_at` (partial, `status = 'CLOSED'`).

Gerçek veri hacmi olmadan (`EXPLAIN ANALYZE` çalıştıracak canlı bir
proje yok) daha fazla index eklemek tahminden ibaret kalır — kitchen/
kasa panolarının kullandığı `business_id` tekli index'leri şimdilik
yeterli (bir işletmenin aktif sipariş kalemi sayısı küçük kalacağı
için). Gerçek kullanım verisiyle `EXPLAIN ANALYZE` çalıştırmak,
sonraki bir performans turunun ilk adımı olmalı.
