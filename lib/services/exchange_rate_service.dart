import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Fetches daily exchange rates from open.er-api.com (free, no API key),
/// relative to USD as the pivot currency, and caches results in SharedPreferences.
/// Includes offline fallback rates for all 62 supported currencies.
class ExchangeRateService {
  static const _ratesKey = 'er_rates';
  static const _fetchedKey = 'er_fetched_at';
  static const _attemptedKey = 'er_attempted_at';
  static const _staleAfter = Duration(hours: 24);
  static const _minRetryInterval = Duration(minutes: 15);
  static const _apiUrl = 'https://open.er-api.com/v6/latest/USD';

  static const _goldApiPrimary =
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/xau.min.json';
  static const _goldApiFallback =
      'https://latest.currency-api.pages.dev/v1/currencies/xau.min.json';

  static const Map<String, double> fallbackRates = {
    'USD': 1.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'BRL': 5.15,
    'CAD': 1.37,
    'AUD': 1.52,
    'EGP': 50.50,
    'SAR': 3.75,
    'AED': 3.67,
    'KWD': 0.31,
    'QAR': 3.64,
    'BHD': 0.376,
    'OMR': 0.385,
    'JOD': 0.709,
    'MAD': 10.05,
    'TND': 3.12,
    'LYD': 4.85,
    'DZD': 134.5,
    'SDG': 601.0,
    'NGN': 1550.0,
    'GHS': 15.2,
    'KES': 129.0,
    'ZAR': 18.2,
    'ETB': 120.0,
    'TZS': 2680.0,
    'UGX': 3700.0,
    'RWF': 1350.0,
    'XOF': 605.0,
    'XAF': 605.0,
    'MZN': 63.8,
    'ZMW': 26.5,
    'JPY': 154.0,
    'CNY': 7.24,
    'INR': 84.0,
    'KRW': 1380.0,
    'IDR': 15800.0,
    'MYR': 4.42,
    'SGD': 1.34,
    'THB': 34.5,
    'VND': 25300.0,
    'PHP': 58.0,
    'PKR': 278.0,
    'BDT': 119.5,
    'LKR': 295.0,
    'NPR': 134.5,
    'MMK': 2100.0,
    'TWD': 32.3,
    'HKD': 7.78,
    'ILS': 3.72,
    'TRY': 34.2,
    'CHF': 0.88,
    'SEK': 10.7,
    'NOK': 10.9,
    'DKK': 6.88,
    'PLN': 4.02,
    'CZK': 23.4,
    'HUF': 375.0,
    'RON': 4.58,
    'BGN': 1.80,
    'RUB': 97.0,
    'UAH': 41.2,
    'GEL': 2.72,
  };

  Future<Map<String, double>> getRates() async {
    return await _loadCached() ?? Map<String, double>.from(fallbackRates);
  }

  Future<Map<String, double>?> forceRefresh() => _fetchAndCache();

  Future<double?> fetchGoldRate() => _fetchGoldRate();

  Future<void> patchCachedXau(double xauRate) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ratesKey);
    if (raw == null) {
      return;
    }
    try {
      final map = (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
      map['XAU'] = xauRate;
      await prefs.setString(_ratesKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<DateTime?> lastFetchedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final fetched = prefs.getString(_fetchedKey);
    if (fetched == null) {
      return null;
    }
    return DateTime.tryParse(fetched);
  }

  double? convert(
    double amount,
    String from,
    String to,
    Map<String, double> rates,
  ) {
    if (from == to) {
      return amount;
    }
    final fromRate = rates[from] ?? fallbackRates[from];
    final toRate = rates[to] ?? fallbackRates[to];
    if (fromRate == null || toRate == null || fromRate == 0) {
      return null;
    }
    return amount / fromRate * toRate;
  }

  Future<bool> shouldAttemptFetch() async {
    if (await isFresh()) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final lastAttempt = prefs.getString(_attemptedKey);
    if (lastAttempt == null) {
      return true;
    }
    final parsed = DateTime.tryParse(lastAttempt);
    if (parsed == null) {
      return true;
    }
    return DateTime.now().difference(parsed) >= _minRetryInterval;
  }

  Future<String?> _httpGet(String url, Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        return null;
      }
      return await response.transform(utf8.decoder).join().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, double>?> _fetchAndCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_attemptedKey, DateTime.now().toIso8601String());
    try {
      final body = await _httpGet(_apiUrl, const Duration(seconds: 8));
      if (body == null) {
        return null;
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['result'] != 'success') {
        return null;
      }

      final rawRates = json['rates'] as Map<String, dynamic>;
      final rates = rawRates.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );

      final hasXau = rates.containsKey('XAU') && (rates['XAU'] ?? 0) > 0;
      if (!hasXau) {
        final xauRate = await _fetchGoldRate();
        if (xauRate != null) {
          rates['XAU'] = xauRate;
        }
      }

      await prefs.setString(_ratesKey, jsonEncode(rates));
      await prefs.setString(_fetchedKey, DateTime.now().toIso8601String());
      return rates;
    } catch (_) {
      return null;
    }
  }

  Future<double?> _fetchGoldRate() async {
    for (final url in [_goldApiPrimary, _goldApiFallback]) {
      try {
        final body = await _httpGet(url, const Duration(seconds: 5));
        if (body == null) {
          continue;
        }
        final data = jsonDecode(body);
        if (data is! Map) {
          continue;
        }
        final xauMap = data['xau'];
        if (xauMap is! Map) {
          continue;
        }
        final usdPrice = xauMap['usd'];
        final priceUsd = usdPrice is num
            ? usdPrice.toDouble()
            : double.tryParse(usdPrice?.toString() ?? '');
        if (priceUsd != null && priceUsd > 0) {
          return 1.0 / priceUsd;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<Map<String, double>?> getCached() => _loadCached();

  Future<bool> isFresh() => _isFresh();

  Future<Map<String, double>?> _loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_ratesKey);
    if (raw == null) {
      return null;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isFresh() async {
    final prefs = await SharedPreferences.getInstance();
    final fetched = prefs.getString(_fetchedKey);
    if (fetched == null) {
      return false;
    }
    final parsed = DateTime.tryParse(fetched);
    if (parsed == null) {
      return false;
    }
    return DateTime.now().difference(parsed) < _staleAfter;
  }
}
