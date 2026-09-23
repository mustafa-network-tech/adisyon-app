# Google Play Mağaza Sayfası

Play Console → **Büyüme → Mağazadaki varlık → Ana mağaza girişi** için hazır metin ve görseller. Varsayılan dil: Türkçe (tr-TR).

## Görseller

| Alan | Dosya | Play şartı |
|---|---|---|
| Uygulama simgesi | `apps/mobile/assets/store/play_icon_512.png` | 512×512 PNG, en fazla 1 MB |
| Öne çıkan görsel | `apps/mobile/assets/store/feature_graphic_1024x500.png` | 1024×500 PNG/JPEG, şeffaflık yok |
| Telefon ekran görüntüleri | `apps/mobile/assets/store/screenshots/phone/` (7 adet) | 2–8 adet, 1080×1920 dikey, şeffaflık yok |
| 7 inç tablet ekran görüntüleri | `apps/mobile/assets/store/screenshots/tablet7/` (5 adet) | 1920×1080 yatay |
| 10 inç tablet ekran görüntüleri | `apps/mobile/assets/store/screenshots/tablet10/` (5 adet) | 1920×1080 yatay |

Ekran görüntüleri, uygulamanın gerçek ekranlarının örnek verilerle (hayali "Lale Cafe & Restoran") çizilmiş halidir. Gerçek müşteri verisi içermez. Yeniden üretmek için:

```bash
cd apps/mobile
flutter test tool/store_screenshots/store_screenshots_test.dart   # ham ekranlar -> build/store_screenshots/raw/<cihaz>
python tool/store_screenshots/frame_screenshots.py                  # başlıklı görseller -> assets/store/screenshots/<cihaz>
```

Tablet görüntüleri gerçek tablet düzeninde çizilir: 7 inç 1024×576 dp, 10 inç 1280×720 dp, yatay. Tablet ekran görüntüleri yüklendiğinde uygulama Play'de tablet kullanıcılarına da önerilebilir.

## Metinler

**Uygulama adı** (en fazla 30 karakter):

```
MK Adisyon – Adisyon ve Kasa
```

**Kısa açıklama** (en fazla 80 karakter):

```
Restoran ve kafeler için adisyon, sipariş, mutfak ve kasa uygulaması.
```

**Tam açıklama** (en fazla 4000 karakter):

```
MK Adisyon; restoran, kafe ve benzeri işletmelerin masa, sipariş, mutfak ve kasa süreçlerini tek bir sistemde yönetmesini sağlar. Garson siparişi telefondan alır, mutfak siparişi anında görür, kasa hesabı kapatır.

GARSON
• Masaları alan alan görün: boş, dolu, hesap istendi
• Kategorili menüden ürün seçin, ürün notu ekleyin
• Siparişi tek dokunuşla mutfağa gönderin
• Ürünlerin mutfaktaki durumunu (yeni, hazırlanıyor, hazır, servis edildi) anlık takip edin

MUTFAK
• Açık siparişler masa masa, geliş sırasıyla
• Bekleme süresi uzayan siparişler öne çıkar
• Ürün durumunu tek dokunuşla güncelleyin

KASA
• Hesap isteyen masalar listenin başında
• Nakit, kart ve parçalı ödeme; kalan tutar otomatik hesaplanır
• Hatalı ürünü iptal edin, hesabı kapatın

İŞLETME YÖNETİMİ
• Masa, alan, ürün, kategori ve personel yönetimi web panelinden
• Rol bazlı yetki: yönetici, kasa, garson, mutfak
• Satış raporları ve işlem geçmişi
• QR Menü (Ultra Süper planında)

PLANLAR
Standart, Süper ve Ultra Süper planları masa, garson ve alan sayısına göre ayrılır; aylık ve yıllık seçenek vardır. Yeni işletmeler ücretsiz deneme ile başlar ve deneme süresince tüm özellikleri kullanır. Abonelik, uygulama içinden Google Play üzerinden başlatılır ve Google Play > Ödemeler ve abonelikler bölümünden istediğiniz zaman iptal edilebilir.

Uygulamayı kullanmak için bir MK Adisyon işletme hesabı gerekir. İşletme hesabı web sitemizden birkaç dakikada oluşturulur; personel hesapları işletme yöneticisi tarafından eklenir.

MK Adisyon bir ödeme kuruluşu, yazar kasa (ÖKC) veya e-Fatura/e-Arşiv entegratörü değildir; sistemdeki ödeme kayıtları işletmenin iç takibi içindir.
```

Tam açıklamada kampanya süresi ("14 gün ücretsiz" gibi) **yazmayın**. Google Play kampanya uygunluğu kullanıcıya göre değişir ve sabit bir süre yazmak Play politikasına aykırı olabilir.

## Diğer alanlar

| Alan | Değer |
|---|---|
| Uygulama kategorisi | İş (Business) |
| Etiketler | Restoran, İşletme yönetimi, Satış noktası (Play'in önerdiği etiketlerden seçin) |
| İletişim e-postası | Destek adresiniz (zorunlu) |
| Web sitesi | Web panelinin adresi |
| Gizlilik politikası | https://mustafaoner.net/kvkk-veri-isleme-gizlilik-politikalari/mk-adisyon/gizlilik |

**Uygulama içeriği.**

- Data safety formu için `docs/LEGAL_AND_DATA_SAFETY.md` §5'e bakın.
- İçerik derecelendirmesi anketinde şiddet, cinsellik, kumar ve kullanıcılar arası iletişim sorularının hepsine "Hayır" yanıtı verin.
- Hedef kitle: 18 yaş ve üzeri.
- Reklam: yok.
- Uygulama erişimi: demo hesap bilgilerini girin.
