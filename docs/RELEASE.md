# MK Adisyon — Yayın Kontrol Listesi

## 1. Supabase (her sürümden önce)

- [ ] `supabase/migrations/` altındaki yeni migration'lar production
      projesine uygulandı (`supabase db push` veya SQL Editor, dosya sırasıyla).
- [ ] `supabase/tests/rls_penetration_tests.sql` production'a benzer bir
      ortamda çalıştırıldı, tüm senaryolar geçti (ROLLBACK ile biter).
- [ ] Authentication → URL Configuration: **Site URL** production domaini;
      **Redirect URLs** listesinde `https://<domain>/auth/callback` var.
- [ ] İlk platform admin tanımlı (`platform_admins`, bkz. kök README).

## 2. Web (Vercel)

Vercel → Project → Settings → Environment Variables (Production):

| Değişken | Not |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | public |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | public (anon/publishable key) |
| `SUPABASE_SERVICE_ROLE_KEY` | **gizli** — asla `NEXT_PUBLIC_` önekiyle değil |
| `NEXT_PUBLIC_SITE_URL` | `https://<domain>` — davet/callback linkleri buradan üretilir |

- [ ] Root Directory: `apps/web`.
- [ ] Yerelde `npm run lint && npm run build` temiz.
- [ ] Deploy sonrası duman testi: `/kayit` → yeni işletme; `/isletme`,
      `/kasa`, `/mutfak`, `/raporlar`, `/super-admin` açılıyor;
      `/menu/<businessId>` QR menü açık planda görünüyor.

Web'de aktif modüller: Süper Admin (`/super-admin`), İşletme Yönetimi
(`/isletme`), Kasa (`/kasa`, CASHIER + BUSINESS_ADMIN), Mutfak (`/mutfak`,
KITCHEN + BUSINESS_ADMIN), Raporlar, QR Menü. Garson yalnızca Android.

## 3. Android (Google Play)

Ayrıntılı komutlar: [`apps/mobile/README.md`](../apps/mobile/README.md#play-store-yayını).

- [ ] Upload keystore oluşturuldu, **repo dışında yedeklendi**;
      `android/key.properties` dolduruldu.
- [ ] `dart_define.json` production Supabase URL + anon key içeriyor.
- [ ] `pubspec.yaml` `version` artırıldı (build numarası her yüklemede büyür).
- [ ] `scripts/build_release.ps1` ile AAB üretildi; `build/symbols` saklandı.
- [x] Uygulama ikonu ve splash hazır (adisyon fişi + onay rozeti,
      `assets/icon/`). Play Console görselleri: `assets/store/play_icon_512.png`
      (512×512 uygulama simgesi) ve `assets/store/feature_graphic_1024x500.png`
      (öne çıkan görsel). Ekran görüntüleri henüz yok.

Play Console (ilk yayında bir kez):

- [ ] Gizlilik politikası URL'si (zorunlu — uygulama e-posta ile giriş
      yapıyor):
      https://mustafaoner.net/kvkk-veri-isleme-gizlilik-politikalari/mk-adisyon
      (alt sayfalar: `/gizlilik`, `/kvkk`, `/kullanim-kosullari` — uygulama
      içi bağlantılar `legal-links.ts` / `legal_links.dart` üzerinden).
- [ ] Veri güvenliği (Data safety) formu: e-posta, ad, telefon toplanıyor;
      aktarım HTTPS ile şifreli; üçüncü tarafla paylaşım yok.
- [ ] İçerik derecelendirmesi anketi, hedef kitle (18+ / işletme uygulaması).
- [ ] İnceleme ekibi için test hesabı (ör. WAITER rolünde demo kullanıcı)
      "Uygulama erişimi" bölümüne girildi — giriş zorunlu olduğu için
      aksi halde inceleme reddedilir.
- [ ] Önce **Dahili test** kanalına yükle, gerçek cihazda garson /
      mutfak / kasa akışlarını dene, sonra üretime terfi ettir.
