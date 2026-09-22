# adisyon

MK Adisyon - restoran ve kafeler icin adisyon ve POS uygulamasi

Faz 4: Supabase Auth, oturum yönetimi, rol bazlı yönlendirme (WAITER /
KITCHEN / CASHIER / BUSINESS_ADMIN / platform admin uyarısı).

Faz 5: Garson akışı tam çalışır durumda — alan seçimi → masa ızgarası
(canlı, Realtime) → masa açma → ürün/kategori seçimi → adet/not → sepeti
mutfağa gönderme → sipariş durumu takibi → hesap isteme → (yalnızca
henüz `NEW` durumundaki kalemler için) iptal. `lib/features/waiter/`
altında. Mutfak/kasa ekranları Faz 6–7'de eklenecek — bkz.
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

Release build de aynı şekilde:

```bash
flutter build appbundle --dart-define-from-file=dart_define.json
```

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
