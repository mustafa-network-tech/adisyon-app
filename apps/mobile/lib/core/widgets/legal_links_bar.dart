import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/legal_links.dart';

/// Links to the privacy policy, terms and KVKK notice, opened in the
/// external browser (no WebView).
class LegalLinksBar extends StatelessWidget {
  const LegalLinksBar({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: Colors.grey.shade700,
      textStyle: const TextStyle(fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 36),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        TextButton(
          style: style,
          onPressed: () => _open(context, LegalLinks.privacy),
          child: const Text('Gizlilik Politikası'),
        ),
        TextButton(
          style: style,
          onPressed: () => _open(context, LegalLinks.terms),
          child: const Text('Kullanım Koşulları'),
        ),
        TextButton(
          style: style,
          onPressed: () => _open(context, LegalLinks.kvkk),
          child: const Text('KVKK Aydınlatma Metni'),
        ),
      ],
    );
  }
}
