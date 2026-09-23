import 'dart:convert';
import 'dart:io';

import '../../../core/config/app_config.dart';

class VerifyResult {
  const VerifyResult({required this.ok, this.errorCode});

  final bool ok;
  final String? errorCode;

  /// Worth retrying later (server/network), as opposed to a rejected token.
  bool get isTransient =>
      !ok &&
      (errorCode == null ||
          errorCode == 'PLAY_UNAVAILABLE' ||
          errorCode == 'VERIFY_FAILED' ||
          errorCode == 'NETWORK' ||
          errorCode == 'BILLING_NOT_CONFIGURED');
}

/// Sends a Google Play purchase token to the web backend, which verifies
/// it with the Play Developer API and updates the subscription. The app
/// sends nothing but the token and the user's session -- no plan, price
/// or "active" flag.
class PurchaseVerifier {
  const PurchaseVerifier();

  bool get isConfigured => AppConfig.webBaseUrl.isNotEmpty;

  Future<VerifyResult> verify({
    required String purchaseToken,
    required String accessToken,
  }) async {
    if (!isConfigured) {
      return const VerifyResult(ok: false, errorCode: 'BILLING_NOT_CONFIGURED');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(
        Uri.parse('${AppConfig.webBaseUrl}/api/play/verify'),
      );
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
        ..contentType = ContentType.json;
      request.write(jsonEncode({'purchaseToken': purchaseToken}));
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) return const VerifyResult(ok: true);
      String? code;
      try {
        code = (jsonDecode(body) as Map<String, dynamic>)['error'] as String?;
      } catch (_) {}
      return VerifyResult(ok: false, errorCode: code);
    } catch (_) {
      return const VerifyResult(ok: false, errorCode: 'NETWORK');
    } finally {
      client.close();
    }
  }
}
