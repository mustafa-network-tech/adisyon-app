# Yasal Metin ve Data Safety Güncellemeleri (abonelik açılışı)

Yasal metinler repoda değil, `mustafaoner.net/kvkk-veri-isleme-gizlilik-politikalari/mk-adisyon/*` adresinde yayında. Aşağıdaki değişiklikler, Google Play aboneliği ve iki aşamalı deneme devreye girdiğinde teknik davranışla uyum içindir. **Yayına almadan önce hukuk danışmanınıza onaylatın.** Tırnak içindeki "Mevcut" metinler 2026-09-25 tarihli sayfadan alınmıştır.

## 1. Kullanım Koşulları

### Madde 4, Deneme süresi

- **Mevcut:** "7 günlük ücretsiz deneme ile başlar. Deneme için ödeme bilgisi istenmez ve deneme sonunda otomatik ücretlendirme yapılmaz."
- **Önerilen:**
  > Yeni işletmeler, kayıt anında geçerli olan süre boyunca (şu an 3 gün) MK Adisyon ücretsiz denemesi ile başlar. Bu deneme için ödeme bilgisi istenmez ve deneme sonunda otomatik ücretlendirme yapılmaz. Deneme süresince en üst planın (Ultra Süper) tüm özellikleri kullanılabilir. Hizmet Sağlayıcı yeni kayıtlar için deneme süresini değiştirebilir; değişiklik başlamış denemeleri etkilemez. Her kullanıcı yalnızca bir işletme için deneme alabilir.
  >
  > Google Play üzerinden zaman zaman ücretsiz dönem içeren abonelik kampanyaları sunulabilir. Bu kampanyalarda ödeme yöntemi Google Play tarafından alınır; ücretsiz dönemin süresi, uygunluk koşulları ve sonrasında uygulanacak fiyat satın alma öncesinde Google Play ekranında gösterilir. Ücretsiz dönem bitmeden Google Play üzerinden iptal edilmezse seçilen plan için ücretli abonelik otomatik olarak başlar. Google Play ücretsiz dönemi boyunca da en üst planın tüm özellikleri kullanılabilir; dönem sonunda satın alınan planın limitleri geçerli olur.

### Madde 5, Abonelik, ücret ve ödeme

- **Mevcut:** "…Google Play üzerinden abonelik satın alma şu anda henüz etkin değildir." ve "Google Play aboneliği etkinleştirildiğinde…"
- **Önerilen:**
  > Ücretli abonelikler yalnızca MK Adisyon Android uygulamasından, Google Play faturalandırma sistemi üzerinden işletme yöneticisi tarafından başlatılır. Web sitesi veya başka bir kanal üzerinden çevrimiçi ödeme alınmaz. Plan ücreti, faturalandırma dönemi (aylık/yıllık), varsa kampanya koşulları ve yenileme bilgileri satın alma öncesinde Google Play ekranında gösterilir; geçerli fiyat Google Play'de gösterilen fiyattır. Abonelik, iptal edilene kadar her dönem sonunda otomatik yenilenir. Ödeme, otomatik yenileme, iptal ve iade işlemlerinde Google Play'in koşulları ve politikaları geçerlidir.
  >
  > Plan yükseltmeleri hemen, plan düşürmeleri bir sonraki yenileme tarihinde geçerli olur. Plan değişikliği yeni bir ücretsiz dönem hakkı doğurmaz. Daha düşük bir plana geçildiğinde mevcut masa, garson ve alan kayıtları silinmez; yalnızca yeni plan limitini aşan yeni kayıt eklenemez.
  >
  > Google Play ödemenin alınamadığını bildirirse Google Play'in tanıdığı ek süre boyunca erişim devam eder; ödeme alınamazsa hesap kısıtlanır (yeni adisyon açılamaz, veriler korunur).

Bu maddede "Hesabın silinmesi Google Play aboneliğini otomatik olarak iptal etmez." cümlesi aynen kalmalı.

### Madde 7 ve genel

Değişiklik gerekmiyor. Tek işletme kuralı Madde 4'e eklendi. Çok şubeli kullanım "teklif" kapsamındadır; bu ifade sözleşmede yoksa eklenebilir.

## 2. Gizlilik Politikası

**Android uygulaması tanımı.**

- **Mevcut:** "Android uygulaması, mevcut bir işletme hesabına bağlı personelin giriş yapıp çalışması içindir."
- **Önerilen:** "Android uygulaması, mevcut bir işletme hesabına bağlı personelin giriş yapıp çalışması ve işletme yöneticisinin aboneliğini Google Play üzerinden başlatıp yönetmesi içindir."

**İzinler.**

- **Mevcut:** "MK Adisyon Android uygulaması yalnızca internet erişimi izni ister."
- **Önerilen:** "MK Adisyon Android uygulaması internet erişimi ve Google Play faturalandırma (com.android.vending.BILLING) izni ister. …" Cümlenin geri kalanı aynen kalır. Faturalandırma izni kullanıcıya ayrı bir izin ekranı göstermez, ancak manifestte yer aldığı için doğru beyan edilmelidir.

**Ödeme sağlayıcıları.**

- **Mevcut:** "şu an web'de veya uygulama içinde çevrimiçi ödeme alınmaz. Google Play üzerinden abonelik satışı etkinleştirildiğinde satın alma Google Play tarafından yürütülür."
- **Önerilen:**
  > **Google Play (Google LLC / Google Ireland Ltd.):** Abonelik satın alma, ödeme, yenileme, iptal ve iade işlemlerini Google Play yürütür; ödeme kartı ve fatura bilgilerini yalnızca Google işler, MK Adisyon bu bilgilere erişmez. Aboneliği doğrulamak ve işletme hesabını etkinleştirmek için Google Play'den şu bilgileri alır ve saklarız: satın alma belirteci (purchase token), sipariş numarası, abonelik ürünü ve dönemi, abonelik durumu (aktif, ücretsiz dönem, ek süre, askıda, iptal, süresi dolmuş, iade), başlangıç ve yenileme/bitiş tarihleri, otomatik yenileme durumu ve Google'ın doğrulama yanıtı. Satın alma, Google'a yalnızca işletme hesabının teknik kimliği (rastgele bir kimlik; ad, e-posta gibi kişisel veri değil) ile ilişkilendirilir.

**Amaçlar (mevcut "Deneme süresini, aboneliği ve faturalamayı yönetmek." maddesine ek).** "Google Play aboneliklerini sunucu tarafında doğrulamak, yenileme/iptal bildirimlerini işlemek ve kötüye kullanımı (ör. aynı kullanıcının tekrar tekrar deneme alması) önlemek."

**Saklama.** Abonelik ve satın alma kayıtları, fatura ve ödeme kayıtlarıyla aynı yasal süre boyunca saklanır. KVKK metnindeki "10 yıl" ifadesi ile tutarlı olmalı.

## 3. KVKK Aydınlatma Metni

- **Veri kategorisi**, mevcut "…Ücretli abonelik başlatıldığında fatura ve ödeme kayıtları da işlenir…" cümlesine ek: "Google Play abonelik kayıtları: satın alma belirteci, sipariş numarası, abonelik ürünü/dönemi, durumu, tarihleri, ücretsiz dönem bilgisi."
- **Amaç.** "7 günlük deneme süresinin…" → "Ücretsiz deneme süresinin (MK Adisyon denemesi ve Google Play kampanyaları), aboneliğin, faturalamanın ve iptalin yönetilmesi." **Not:** "7 günlük" ifadesi artık yanlış.
- **Alıcılar, ödeme sağlayıcıları.** "şu an … çevrimiçi ödeme alınmaz … etkinleştirildiğinde…" ifadesini kaldırın. Yerine: "Google Play (abonelik satın alma ve doğrulama). Satın alma işlemini Google Play yürütür ve kart bilgilerini yalnızca Google işler."
- **Yurt dışına aktarım.** Google Play doğrulaması, Google sunucularıyla veri alışverişi içerir. Madde 7'deki aktarım mekanizmasının Google'ı da kapsadığını hukuk danışmanınıza teyit ettirin.

## 4. Hesap silme metni

Şu cümleleri ekleyin:

> "Hesabınızı silmek Google Play aboneliğinizi iptal etmez; aboneliği Google Play > Ödemeler ve abonelikler'den ayrıca iptal edin."
>
> "Abonelik ve satın alma kayıtları yasal saklama yükümlülüğü süresince tutulur."

## 5. Google Play Data safety formu

Formu Play Console → Uygulama içeriği → Veri güvenliği üzerinden siz doldurmalısınız. Önerilen yanıtlar:

| Soru | Yanıt |
|---|---|
| Uygulama kullanıcı verisi topluyor veya paylaşıyor mu? | **Evet** |
| Aktarılan tüm veriler şifreleniyor mu? | **Evet** (HTTPS) |
| Kullanıcılar verilerinin silinmesini isteyebilir mi? | **Evet**. Hesap silme talep sayfasının adresini girin. |

**Toplanan veri türleri:**

| Kategori → tür | Toplanıyor | Paylaşılıyor | Zorunlu | Amaç |
|---|---|---|---|---|
| Kişisel bilgiler → Ad | Evet | Hayır | Evet | Uygulama işlevselliği, Hesap yönetimi |
| Kişisel bilgiler → E-posta adresi | Evet | Hayır | Evet | Uygulama işlevselliği, Hesap yönetimi |
| Kişisel bilgiler → Telefon numarası | Evet | Hayır | Hayır (isteğe bağlı) | Hesap yönetimi |
| **Finansal bilgiler → Satın alma geçmişi** *(yeni)* | **Evet** | **Hayır** | **Evet** | **Uygulama işlevselliği, Hesap yönetimi** |
| Uygulama etkinliği → Diğer kullanıcı tarafından oluşturulan içerik (siparişler, ürünler, adisyonlar) | Evet | Hayır | Evet | Uygulama işlevselliği |
| Uygulama bilgileri ve performans | Hayır | — | — | Crash/analitik SDK'sı yok |
| Konum, Fotoğraf, Kişiler, Cihaz kimlikleri | Hayır | — | — | — |

**Beyan etmeyin:**

- **Finansal bilgiler → Kullanıcı ödeme bilgileri.** Kart bilgilerini yalnızca Google işliyor; uygulama bunlara erişmiyor.
- **Google Play Billing'in kendi topladığı veriler.** Geliştirici bunları beyan etmez.

**Paylaşım.** "Hayır" doğru yanıttır. Hizmet sağlayıcılara (Supabase, Vercel) veri işleyen sıfatıyla yapılan aktarım, Play tanımına göre "paylaşım" sayılmaz. Satın alma doğrulaması için Google'a giden istek de Google'ın kendi verisi üzerinedir.

**Diğer Play Console bölümleri:**

- **Reklamlar:** "Hayır".
- **Mağaza sayfası:** Abonelik ürünleri aktif olunca "Uygulama içi satın alma içerir" etiketini Play otomatik ekler.
- **Uygulama erişimi (inceleme):** İnceleme ekibinin satın alma ekranını görebilmesi için işletme yöneticisi rolünde bir demo hesap verin. Demo işletmenin denemesi sürüyor olmalı ya da Süper Admin'den ACTIVE yapılmış olmalı. İnceleme ekibinin ücret ödemeden satın alma akışını görebilmesi için gerekirse inceleme notuna açıklama ekleyin.
