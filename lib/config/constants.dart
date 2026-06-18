import 'dart:io' show Platform;

class AppConstants {
  // ─── API ──────────────────────────────────────────────────────────────────
  static const String baseUrl = 'https://www.kiraclubs.com/api/v1';

  // ─── Token Storage Key ────────────────────────────────────────────────────
  static const String tokenKey = 'auth_token';
  static const String userKey  = 'auth_user';

  // ─── Agora ────────────────────────────────────────────────────────────────
  static const String agoraAppId = 'YOUR_AGORA_APP_ID';

  // ─── OneSignal ────────────────────────────────────────────────────────────
  static const String oneSignalAppId = '4d534813-d8d3-438c-999c-1056039bbbc5';

  // ─── Google Play Product IDs ──────────────────────────────────────────────
  static List<String> get tokenProducts => [
    'tokens_100',
    Platform.isIOS ? 'tokens_300_ios' : 'tokens_300',
    'tokens_600',
    'tokens_1500',
    'tokens_3000',
  ];

  static Map<String, int> get tokenAmounts => {
    'tokens_100':  100,
    Platform.isIOS ? 'tokens_300_ios' : 'tokens_300':  300,
    'tokens_600':  600,
    'tokens_1500': 1500,
    'tokens_3000': 3000,
  };

  static const List<String> vipProducts = [
    'vip_silver_month',
    'vip_gold_month',
    'vip_platin_month',
  ];

  static const Map<String, String> vipLabels = {
    'silver':   'Silver VIP',
    'gold':     'Gold VIP',
    'platinum': 'Platinum VIP',
  };
}
