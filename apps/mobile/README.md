# adisyon

MK Adisyon - restoran ve kafeler icin adisyon ve POS uygulamasi

Faz 4: Supabase Auth, oturum yönetimi, rol bazlı yönlendirme (WAITER /
KITCHEN / CASHIER / BUSINESS_ADMIN / platform admin uyarısı).

Faz 5: Garson akışı tam çalışır durumda — alan seçimi → masa ızgarası
(canlı, Realtime) → masa açma → ürün/kategori seçimi → adet/not → sepeti
mutfağa gönderme → sipariş durumu takibi → hesap isteme → (yalnızca
henüz `NEW` durumundaki kalemler için) iptal. `lib/features/waiter/`
altında.

Faz 6: Mutfak ekranı (`lib/features/kitchen/`) — masa bazlı, canlı
sipariş panosu; her kalem için NEW→PREPARING→READY→SERVED geçiş
butonları, fiyat/toplam göstermiyor. Aynı akış web'de `/mutfak` altında
da var.

Faz 7: Kasa ekranı (`lib/features/cashier/`) — açık masalar ızgarası
(tutar + hesap-istendi rozeti) → hesap detayı: kalem listesi (iptal
seçeneğiyle), parçalı ödeme (Nakit/Kart/Diğer), ödeme iptali, tam
ödenince "Hesabı Kapat", hiç ödeme yoksa "Siparişi İptal Et". Aynı akış
web'de `/kasa` altında da var.

Faz 9: deneme süresi dolmuş/askıya alınmış bir işletme artık yeni masa
açamıyor (mevcut açık hesabı ödeyip kapatmak hep serbest) — garson
ekranı bunu `core/utils/errors.dart` üzerinden anlaşılır bir mesajla
gösteriyor. Plan limitleri (masa/garson/kullanıcı) web'deki işletme
yönetim panelinde aynı şekilde uygulanıyor — bkz.
[../../docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md).

## Çalıştırma

Supabase anon key gibi public-ama-yapılandırılabilir değerler
`--dart-define` ile veriliyor (hiçbir zaman kodun içine gömülmüyor,
service role key ise bu uygulamada **hiç bulunmuyor** — bkz. mimari
dokümanın 5. maddesi).

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-public-key
```

Tekrar tekrar yazmamak için `dart_define.example.json`'ı kopyalayıp
kendi değerlerinizi girin (bu dosya `.gitignore`'da):

```bash
cp dart_define.example.json dart_define.json
flutter run --dart-define-from-file=dart_define.json
```

## Play Store yayını

### İmzalama anahtarı (bir kez)

Play Store'a yüklenen her sürüm aynı upload anahtarıyla imzalanmalı.
Anahtarı kaybederseniz uygulamayı güncelleyemezsiniz — `.jks` dosyasını
ve şifreleri repo dışında güvenli bir yere (şifre yöneticisi + yedek)
kaydedin.

```bash
keytool -genkey -v -keystore %USERPROFILE%\mk-adisyon-upload.jks ^
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Ardından `android/key.properties` oluşturun (`.gitignore`'da):

```properties
storePassword=<keystore şifresi>
keyPassword=<anahtar şifresi>
keyAlias=upload
storeFile=C:/Users/<kullanici>/mk-adisyon-upload.jks
```

`key.properties` yoksa Gradle debug anahtarıyla imzalar (yalnızca yerel
test için) — Play Console bu paketi reddeder.

### AAB oluşturma

Her yeni sürümde `pubspec.yaml`'daki `version`'ı artırın (`1.0.1+2`
gibi; `+` sonrasındaki build numarası her yüklemede büyümeli). Sonra:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_release.ps1
```

Script `dart_define.json` ve `key.properties`'i kontrol eder, analiz +
testleri çalıştırır, obfuscate edilmiş AAB'yi
`build/app/outputs/bundle/release/app-release.aab` altına üretir.
`build/symbols` klasörünü her sürüm için saklayın (Play Console crash
raporlarını çözümlemek için gerekir).

## Mimari

`lib/core` paylaşılan altyapı (config, tema, router, widget'lar);
`lib/features` özellik bazlı klasörlenmiş (`auth`, `splash`, `home`).
State management: Riverpod (code generation olmadan, klasik provider
API'si). Yönlendirme: go_router, Supabase auth state'ini dinleyen bir
`ChangeNotifier` köprüsüyle (`GoRouterRefreshStream`) senkronize.

Rol çözümleme (`roleContextProvider`) her zaman Supabase'ten taze veri
okur (RLS'e tabi) — istemci tarafında cache'lenmiş role asla güvenilmez;
web uygulamasındaki `getSessionContext`/`getBusinessAdminContext` ile
aynı prensip.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
