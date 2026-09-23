# Google Play Abonelik Entegrasyonu

Durum: **kod hazır, kimlik bilgileri bekleniyor.** Uygulama tarafında satın alma akışı, sunucu tarafında doğrulama, Google bildirimleri (RTDN) ve günlük uzlaştırma kodu yazıldı. Google kimlik bilgileri ve Play ürünleri tanımlanana kadar sistem kendini güvenli tarafta tutar: uygulama "Abonelik servisi şu an kullanılamıyor" gösterir, `/api/play/*` uç noktaları 503 döner. Sahte bir başarılı satın alma yolu yok.

## 1. İki aşamalı deneme modeli

| Aşama | Nereden yönetilir | Ödeme yöntemi | Haklar |
|---|---|---|---|
| **MK Adisyon uygulama denemesi** | Süper Admin → **Abonelik Ayarları** (0 / 3 / 7 gün; varsayılan 3) | İstenmez | En üst plan (Ultra Süper) |
| **Google Play ücretsiz kampanyası** | Play Console → abonelik → base plan → **teklif (offer)** | Google Play alır | En üst plan (Ultra Süper), ardından satın alınan plan |

- Uygulama denemesinin süresi `subscription_settings.app_trial_days` alanında tutulur ve `create_own_business` bu değeri sunucuda okur. Değişiklik yalnızca yeni işletmelere uygulanır; mevcut denemelerin bitiş tarihleri değişmez. 0 seçilirse yeni işletme aboneliği başlatmadan adisyon açamaz.
- Ücretsiz dönemlerde geçerli plan `subscription_settings.trial_plan_code` alanından okunur (varsayılan `ultra_super`). Masa, garson ve alan limitleri ile QR menü `business_effective_plan_id()` üzerinden veritabanında uygulanır.
- Play kampanyasının süresi (örneğin 14 veya 15 gün) **kodda yok**. Uygulama, Play'in o kullanıcı için döndürdüğü fiyatlandırma aşamalarından metni kendisi üretir: "15 gün ücretsiz, ardından ₺399,00/ay". Kampanyayı Play Console'da değiştirmek için yeni sürüm gerekmez.
- Plan değişikliğinde kampanya teklifi kullanılmaz, yalnızca base plan kullanılır. Yani plan değiştirerek tekrar ücretsiz dönem alınamaz. Kampanya uygunluğunu ise Play Console belirler (bkz. §3).

## 2. Akış ve güvenlik

```
Android (yalnızca BUSINESS_ADMIN)
  └─ Google Play satın alma ekranı (obfuscatedAccountId = business_id, offerToken = Play'in döndürdüğü)
       └─ purchaseToken ─► POST {WEB_BASE_URL}/api/play/verify   (Supabase oturum JWT'si)
            1. JWT → kullanıcı; aktif BUSINESS_ADMIN üyeliği → business_id
            2. Play Developer API purchases.subscriptionsv2.get(token)
            3. Google'ın döndürdüğü obfuscatedExternalAccountId == business_id mi?
            4. record_google_play_subscription(...)   ← service_role; plan ürün + base plan'dan DB'de çözülür
            5. acknowledge (Google, 3 gün içinde onaylanmayan satın almayı iade eder)
Google Play ─ RTDN ─► Pub/Sub (OIDC'li push) ─► POST /api/play/rtdn ─► 2 → 4 → 5
Vercel Cron (günlük 03:00 UTC) ─► GET /api/play/reconcile ─► süresi geçmiş / 20 saattir doğrulanmamış kayıtlar ─► 2 → 4 → 5
```

- İstemci yalnızca token gönderir. Plan, fiyat, durum, bitiş tarihi ve ücretsiz dönem bilgisinin hepsi Google'dan okunur.
- `record_google_play_subscription` ve eski `apply_google_play_verification_result` yalnızca `service_role` tarafından çağrılabilir. anon, authenticated ve PUBLIC çağıramaz (testlerle doğrulandı).
- Bir purchase token başka bir işletmeye bağlıysa reddedilir. Play eşlemesi olmayan ürün reddedilir.
- İşletme durumu, işletmenin **tüm** satın almalarından hesaplanır. Yükseltme veya düşürmede eski token'ın süresinin dolması yeni aboneliği kapatmaz (`linkedPurchaseToken`).
- Süper Admin'in askıya aldığı işletmeyi Play açamaz.
- Service role anahtarı yalnızca web sunucusunda bulunur; Flutter uygulamasında yok.

### Durum eşlemesi

| Play `subscriptionState` | Kayıt | İşletme | Yeni adisyon |
|---|---|---|---|
| ACTIVE (ücretsiz dönem dahil) | ACTIVE | ACTIVE | açılır |
| IN_GRACE_PERIOD | GRACE_PERIOD | GRACE_PERIOD | açılır |
| ON_HOLD, PAUSED | ON_HOLD | EXPIRED | açılmaz |
| CANCELED, süre dolmamış | CANCELLED | ACTIVE | açılır |
| CANCELED, süre dolmuş | CANCELLED | CANCELLED | açılmaz |
| EXPIRED, PENDING_PURCHASE_CANCELED | EXPIRED | EXPIRED | açılmaz |
| RTDN `SUBSCRIPTION_REVOKED` (12) | REVOKED | EXPIRED | açılmaz |
| PENDING | PENDING | değişmez | — |

Ücretsiz dönem, satın alma kalemindeki `offerPhase.freeTrial` alanından okunur. Hiçbir durumda veri silinmez; açık adisyonlar her zaman kapatılabilir.

## 3. Play Console'da oluşturulacak yapı

Ürün ve base plan kimliklerini siz belirleyin; Play bu kimliklerin sonradan değiştirilmesine izin vermez. Aşağıdaki isimler yalnızca öneridir. Oluşturduğunuz kimlikleri **Süper Admin → Planlar → plan detayı → Google Play Eşleştirme** alanlarına girin.

| Plan (`code`) | Abonelik ürünü (öneri) | Base plan | Süre | Fiyat (TRY) |
|---|---|---|---|---|
| standard | `mk_standart` | `monthly` | 1 ay, otomatik yenilenen | 399,00 |
| standard | | `yearly` | 1 yıl, otomatik yenilenen | 4.309,20 |
| super | `mk_super` | `monthly` | 1 ay | 799,00 |
| super | | `yearly` | 1 yıl | 8.629,20 |
| ultra_super | `mk_ultra_super` | `monthly` | 1 ay | 1.899,00 |
| ultra_super | | `yearly` | 1 yıl | 20.509,20 |

**Kampanya teklifi.** Her base plan'a bir teklif ekleyin. Örnek teklif kimliği: `acilis`.

- Aşama: **Ücretsiz deneme**, süre 14 veya 15 gün.
- Uygunluk: **Yeni müşteri edinme → Bu uygulamada daha önce hiç aboneliği olmamış kullanıcılar.** Bu seçenek, planlar arasında geçerek tekrar ücretsiz dönem alınmasını Play tarafında engeller.
- Kampanyayı sona erdirmek için teklifi devre dışı bırakın. Süreyi değiştirmek için yeni bir teklif oluşturun. Uygulama güncellemesi gerekmez.

**Base plan ayarları.**

- **Ek süre (grace period):** açık bırakın. Bu süre boyunca erişim devam eder.
- **Hesap askısı (account hold):** açık bırakın. Askı süresince erişim kapanır.
- **Duraklatma (pause):** kapatın.

**Fiyatlar.**

- Play kuruşlu yıllık fiyatı kabul etmez veya farklı bir yuvarlama önerirse karar sizin. Uygulama her durumda Play'in gösterdiği fiyatı kullanır; veritabanındaki fiyat yalnızca liste fiyatıdır.
- Uygulama içi mağaza açıklamasına sabit "15 gün ücretsiz" yazmayın. Uygunluk kullanıcıya göre değişir.

**Önkoşul.** Play, abonelik ürünlerini ancak BILLING izni taşıyan bir sürüm yüklendikten sonra açar. Bu izni `in_app_purchase` paketi ekliyor. Önce bir AAB'yi **Dahili test** kanalına yükleyin.

## 4. Google Cloud ve Play Console adımları

1. **Google Cloud projesi** oluşturun ya da mevcut bir projeyi kullanın. **APIs & Services → Google Play Android Developer API → Enable.**
2. **Service account:** IAM → Service Accounts → oluşturun. Cloud rolü gerekmez. **Keys → JSON key** indirin; bu dosyayı repoya koymayın.
3. **Play Console → Kullanıcılar ve izinler → Yeni kullanıcı davet et:** service account e-postasını girin. MK Adisyon uygulaması için şu izinleri verin:
   - "Finansal verileri, siparişleri ve iptal anketi yanıtlarını görüntüleme"
   - "Siparişleri ve abonelikleri yönetme"
4. **Pub/Sub konusu:** örneğin `play-rtdn`. Konunun izinlerine `google-play-developer-notifications@system.gserviceaccount.com` hesabını **Pub/Sub Publisher** olarak ekleyin.
5. **Play Console → Para kazanma ayarları → Gerçek zamanlı geliştirici bildirimleri:**
   - Konu: `projects/<proje-id>/topics/play-rtdn`
   - Bildirim türü: abonelikler
   - "Test bildirimi gönder" ile kurulumu sınayın.
6. **Push aboneliği** (Pub/Sub → Subscriptions → Create):
   - Delivery type: **Push**
   - Endpoint: `https://<web-domain>/api/play/rtdn`
   - **Enable authentication**: bir service account seçin (örneğin ayrı bir `rtdn-push@...` hesabı). Audience olarak endpoint URL'sini girin.
   - Eski projelerde Pub/Sub hizmet ajanına (`service-<proje-no>@gcp-sa-pubsub.iam.gserviceaccount.com`) bu hesap üzerinde **Service Account Token Creator** rolü gerekebilir.
7. **Play Console → Ayarlar → Lisans testi:** test edecek Gmail hesaplarını ekleyin. Bu hesaplar ücret ödemez ve abonelikleri hızlandırılmış sürelerle yenilenir.

## 5. Ortam değişkenleri

Vercel (Production), yalnızca sunucu tarafında; hiçbiri `NEXT_PUBLIC_` önekiyle tanımlanmaz:

| Değişken | Değer |
|---|---|
| `GOOGLE_PLAY_PACKAGE_NAME` | `com.mkdigitalsystems.adisyon` |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | §4.2'deki JSON'un tamamı (ham ya da base64) |
| `GOOGLE_PLAY_RTDN_AUDIENCE` | §4.6'daki audience (örneğin `https://<web-domain>/api/play/rtdn`) |
| `GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT_EMAIL` | §4.6'da push aboneliğine verilen service account e-postası |
| `CRON_SECRET` | Rastgele uzun bir değer (Vercel Cron bunu `Authorization: Bearer` olarak gönderir) |

Flutter (`apps/mobile/dart_define.json`):

| Anahtar | Değer |
|---|---|
| `WEB_BASE_URL` | `https://<web-domain>` (sonunda `/` olmadan). Boş bırakılırsa satın alma "kullanılamıyor" görünür. |

## 6. Test sırası

1. 032 migration'ını uygulayın ve `supabase/tests/verify_20260925000032.sql` ile doğrulayın.
2. Vercel ortam değişkenlerini girip deploy edin.
3. AAB'yi (`WEB_BASE_URL` tanımlı) dahili test kanalına yükleyin, ardından ürünleri ve teklifleri oluşturun.
4. Süper Admin → Planlar ekranında Play kimliklerini girin.
5. Lisans test hesabıyla satın alın. Beklenen sonuçlar:
   - Abonelik ekranında Play'in teklif metni görünür.
   - Satın almadan sonra durum "Google Play ücretsiz dönemi" olur ve Ultra Süper hakları açılır.
   - Süper Admin → Abonelikler ekranında kayıt görünür.
6. Play Console'dan aboneliği iptal edin ve süresinin dolmasını bekleyin; RTDN işletmeyi EXPIRED yapmalı. Ardından `/api/play/reconcile` uç noktasını `CRON_SECRET` ile elle çağırın.
