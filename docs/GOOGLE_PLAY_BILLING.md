# Google Play Abonelik Entegrasyonu

Durum: **hazırlık aşaması.** Plan kataloğu, veritabanı eşlemesi, durum
geçişleri ve güvenli yazma yolu hazır. Gerçek satın alma (Flutter) ve
sunucu tarafı doğrulama (Google Play Developer API) **henüz yok.** Uygulamada
satın alma butonu devre dışı; sahte bir satın alma akışı yok.

## 1. Tek kaynak: `plans` tablosu

| Alan | Anlamı |
|---|---|
| `code` | Sabit iç kimlik: `standard`, `super`, `ultra_super` |
| `name`, `sort_order` | Görünen ad ve sıralama |
| `monthly_price`, `yearly_discount` | Liste fiyatı (TRY) ve yıllık indirim (%) |
| `yearly_price` | **Veritabanı hesaplar:** `round(aylık × 12 × (100 − indirim) / 100, 2)` |
| `max_tables`, `max_waiters`, `max_areas`, `max_branches`, `qr_menu_enabled` | Limitler ve özellikler (`null` = sınırsız) |
| `google_play_product_id` | Play Console abonelik ürün kimliği (şu an boş) |
| `google_play_monthly_base_plan_id`, `google_play_yearly_base_plan_id` | Aynı ürün altındaki base plan kimlikleri (şu an boş) |

`plan_billing_options` görünümü bunu `(plan, dönem) → fiyat / ürün / base plan`
satırlarına açar. Web (`/fiyatlandirma`, `/isletme/abonelik`), Süper Admin ve
Flutter aynı tablodan okur. Play kimlikleri Play Console'da oluşturulduktan
sonra **Süper Admin → Planlar → plan detayı → Google Play Eşleştirme**
alanlarına girilir; kodda hiçbir yerde sabit kimlik yok.

Uygulamada ödeme sırasında gösterilen ve tahsil edilen fiyat **her zaman
Google Play'in döndürdüğü yerelleştirilmiş fiyattır**; tablodaki fiyat
yalnızca katalog/liste fiyatıdır.

## 2. Play Console'da oluşturulacak yapı

Her plan için bir abonelik ürünü, her üründe iki base plan:

| Abonelik (ürün) | Base plan | Süre | Fiyat (TRY) | Teklif |
|---|---|---|---|---|
| Standart | aylık | 1 ay, otomatik yenilenen | 399,00 | 7 gün ücretsiz deneme |
| Standart | yıllık | 1 yıl, otomatik yenilenen | 4.309,20 | 7 gün ücretsiz deneme |
| Süper | aylık | 1 ay | 799,00 | 7 gün ücretsiz deneme |
| Süper | yıllık | 1 yıl | 8.629,20 | 7 gün ücretsiz deneme |
| Ultra Süper | aylık | 1 ay | 1.899,00 | 7 gün ücretsiz deneme |
| Ultra Süper | yıllık | 1 yıl | 20.509,20 | 7 gün ücretsiz deneme |

- Ürün ve base plan kimliklerini siz belirleyin (Play kimlikleri sonradan
  değiştirilemez). Base plan kimlikleri ürün başına benzersizdir; üç üründe
  de `monthly` / `yearly` kullanmak veritabanında desteklenir.
- **Deneme teklifi uygunluğu:** "Yeni müşteri edinme" ve *bu uygulamada daha
  önce hiçbir aboneliği olmamış* seçeneği önerilir. Aksi halde bir kullanıcı
  planlar arasında geçerek her üründe yeniden deneme alabilir.
- Deneme uygunluğu kullanıcıya göre değişir. Mağaza açıklamasına sabit
  "7 gün ücretsiz" yazmayın; uygulama yalnızca Play'in o kullanıcı için
  döndürdüğü teklifi göstermeli.
- **Grace period** açık kalsın (veritabanı `GRACE_PERIOD` sırasında erişimi
  sürdürür). **Account hold** erişimi kapatır (`ON_HOLD → EXPIRED`).
- **Duraklatma (pause)** özelliğini kapatın. `PAUSED` durumu şu an
  eşlenmiyor.
- Yıllık fiyatlarda Play yuvarlama önerirse (örneğin 4.309,99) bunu siz
  onaylayın. Veritabanındaki liste fiyatı aynı kalır, uygulama Play fiyatını
  gösterir.

## 3. Güvenli doğrulama mimarisi (yapılacak)

```
Flutter (BUSINESS_ADMIN)
  └─ launchBillingFlow(obfuscatedAccountId = business_id)
       └─ purchaseToken ─► POST /api/play/verify  (kullanıcı JWT ile)
                              │ 1. JWT → kullanıcı, BUSINESS_ADMIN mi?
                              │ 2. subscriptionsv2.get(package, token)
                              │ 3. obfuscatedExternalAccountId == business_id?
                              │ 4. apply_google_play_verification_result(...)  (service role)
                              │ 5. acknowledge (3 gün içinde, yoksa Google iade eder)
Google Play ── RTDN ─► Pub/Sub ─► POST /api/play/rtdn ─► 2 → 4 (aynı yol)
Günlük tarama: expiry_time geçmiş veya 24 saattir doğrulanmamış kayıtlar ─► 2 → 4
```

- Yazma yolu tek: `apply_google_play_verification_result`. EXECUTE yetkisi
  **yalnızca `service_role`**'de. Bu migration öncesinde `anon` dahil herkes
  çağırabiliyordu, 20260923000029 bunu kapattı.
- `p_plan_id` boş gönderilirse plan, Play'in bildirdiği ürün/base plan'dan
  sunucuda çözülür. İstemci hangi planın açılacağını seçemez.
- İşletme yöneticisi `businesses.plan_id` / `subscription_status` alanlarını
  değiştiremez (`restrict_business_update_to_admin_safe_fields`).
- Plan yükseltme/düşürmede yeni satın alma `linkedPurchaseToken` taşır.
  Doğrulama işi eski token'ı bu bilgiyle kapatmalıdır.

### Durum eşlemesi

| Play (`subscriptionsv2`) | `google_play_purchases.purchase_state` | `businesses.subscription_status` | Yeni adisyon |
|---|---|---|---|
| ACTIVE (deneme teklifi dahil) | ACTIVE | ACTIVE | açılır |
| IN_GRACE_PERIOD | GRACE_PERIOD | GRACE_PERIOD | açılır |
| ON_HOLD | ON_HOLD | EXPIRED | açılmaz |
| CANCELED, süre dolmamış | CANCELLED | ACTIVE | açılır |
| CANCELED, süre dolmuş | CANCELLED | CANCELLED | açılmaz |
| EXPIRED | EXPIRED | EXPIRED | açılmaz |
| RTDN `SUBSCRIPTION_REVOKED` | REVOKED | EXPIRED | açılmaz |
| PENDING | PENDING | değişmez | — |

Hiçbir durumda veri silinmez. Açık adisyonlar her durumda kapatılabilir.

## 4. Flutter tarafında yapılacaklar

1. `in_app_purchase` paketini ekleyin. Paket `com.android.vending.BILLING`
   iznini otomatik ekler.
2. Ürün kimliklerini `plans` tablosundan okuyun (`queryProductDetails`).
   Base plan ve teklifleri `GooglePlayProductDetails` → `subscriptionOfferDetails`
   içinden seçin. Play yalnızca kullanıcının uygun olduğu teklifleri döndürür;
   deneme rozeti buna göre gösterilmeli.
3. Fiyatı `pricingPhases` içinden gösterin, tablodaki fiyatı değil.
4. `PurchaseParam(applicationUserName: businessId)` ile satın alma başlatın
   (Android'de `obfuscatedAccountId` olur).
5. `purchaseStream`'den gelen token'ı `/api/play/verify`'a gönderin. Sunucu
   onaylamadan abonelik aktif sayılmaz. `completePurchase` yalnızca sunucu
   başarılı döndükten sonra çağrılmalı.
6. "Aboneliği yönet" bağlantısı:
   `https://play.google.com/store/account/subscriptions?sku=<ürün>&package=com.mkdigitalsystems.adisyon`
7. Satın alma yalnızca `BUSINESS_ADMIN` rolünde görünür. Uygulama web'deki bir
   ödeme sayfasına yönlendirmemeli.

## 5. Gerekli hesaplar ve kimlik bilgileri

| Ne | Nerede | Not |
|---|---|---|
| Ödeme (merchant) profili | Play Console → Ayarlar → Ödeme profili | Abonelik ürünü oluşturmak için şart |
| Uygulama en az dahili test kanalında | Play Console | Ürünler, BILLING izinli bir sürüm yüklenmeden oluşturulamaz |
| Google Cloud projesi + **Google Play Android Developer API** | Cloud Console | |
| Service account + JSON anahtar | Cloud Console → IAM | Sunucu ortam değişkeni, **gizli** |
| Service account'a yetki | Play Console → Kullanıcılar ve izinler | "Finansal verileri görüntüleme", "Siparişleri ve abonelikleri yönetme" |
| Pub/Sub konusu + push aboneliği | Cloud Console | `google-play-developer-notifications@system.gserviceaccount.com` hesabına Publisher yetkisi verin; push adresi `/api/play/rtdn` |
| RTDN konusu | Play Console → Para kazanma ayarları | |
| Lisans test kullanıcıları | Play Console → Lisans testi | Gerçek ücret alınmadan test |

Önerilen ortam değişkenleri (yalnızca sunucu tarafında):
`GOOGLE_PLAY_PACKAGE_NAME`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`,
`GOOGLE_PLAY_RTDN_AUDIENCE`.

## 6. Açık kararlar

- **Deneme çakışması:** Kayıtta 7 günlük uygulama denemesi zaten başlıyor.
  Play'deki 7 günlük teklif satın alma anında başlar, yani ikisi art arda
  gelirse toplam deneme 14 güne çıkar. Seçenekler: (a) Play teklifini hiç
  oluşturmamak, (b) uygulama denemesi süren işletmelerde Play teklifi
  olmayan base plan'ı sunmak, (c) çakışmayı kabul etmek.
- **Plan düşürme:** Limit üstündeki masa, garson ve alanlar pasife alınmaz,
  yalnızca yenileri engellenir.
- **Vergi ve komisyon:** Play abonelikte %15 komisyon keser. Play'e girilen
  TRY fiyatının vergi durumu ve fatura yükümlülüğü mali müşavirle teyit
  edilmeli.
