/// Public legal documents hosted on the publisher's site. Keep in sync
/// with apps/web/src/lib/legal-links.ts.
class LegalLinks {
  const LegalLinks._();

  static const String _base =
      'https://mustafaoner.net/kvkk-veri-isleme-gizlilik-politikalari/mk-adisyon';

  static final Uri privacy = Uri.parse('$_base/gizlilik');
  static final Uri terms = Uri.parse('$_base/kullanim-kosullari');
  static final Uri kvkk = Uri.parse('$_base/kvkk');
}
