import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'company_service.dart';
import 'exchange_rate_service.dart';
import '../widgets/common_widgets.dart';

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  const CurrencyInfo(this.code, this.symbol, this.name);
}

const List<CurrencyInfo> kCurrencies = [
  CurrencyInfo('USD', r'$', 'US Dollar'),
  CurrencyInfo('EUR', '€', 'Euro'),
  CurrencyInfo('GBP', '£', 'British Pound'),
  CurrencyInfo('BRL', r'R$', 'Brazilian Real'),
  CurrencyInfo('CAD', r'C$', 'Canadian Dollar'),
  CurrencyInfo('AUD', r'A$', 'Australian Dollar'),
  CurrencyInfo('EGP', 'EGP', 'Egyptian Pound'),
  CurrencyInfo('SAR', 'SR', 'Saudi Riyal'),
  CurrencyInfo('AED', 'د.إ', 'UAE Dirham'),
  CurrencyInfo('KWD', 'KD', 'Kuwaiti Dinar'),
  CurrencyInfo('QAR', 'QR', 'Qatari Riyal'),
  CurrencyInfo('BHD', 'BD', 'Bahraini Dinar'),
  CurrencyInfo('OMR', 'OMR', 'Omani Rial'),
  CurrencyInfo('JOD', 'JD', 'Jordanian Dinar'),
  CurrencyInfo('MAD', 'MAD', 'Moroccan Dirham'),
  CurrencyInfo('TND', 'DT', 'Tunisian Dinar'),
  CurrencyInfo('LYD', 'LD', 'Libyan Dinar'),
  CurrencyInfo('DZD', 'DA', 'Algerian Dinar'),
  CurrencyInfo('SDG', 'SDG', 'Sudanese Pound'),
  CurrencyInfo('NGN', '₦', 'Nigerian Naira'),
  CurrencyInfo('GHS', 'GH₵', 'Ghanaian Cedi'),
  CurrencyInfo('KES', 'KSh', 'Kenyan Shilling'),
  CurrencyInfo('ZAR', 'R', 'South African Rand'),
  CurrencyInfo('ETB', 'Br', 'Ethiopian Birr'),
  CurrencyInfo('TZS', 'TSh', 'Tanzanian Shilling'),
  CurrencyInfo('UGX', 'USh', 'Ugandan Shilling'),
  CurrencyInfo('RWF', 'RF', 'Rwandan Franc'),
  CurrencyInfo('XOF', 'CFA', 'West African CFA'),
  CurrencyInfo('XAF', 'FCFA', 'Central African CFA'),
  CurrencyInfo('MZN', 'MT', 'Mozambican Metical'),
  CurrencyInfo('ZMW', 'ZK', 'Zambian Kwacha'),
  CurrencyInfo('JPY', '¥', 'Japanese Yen'),
  CurrencyInfo('CNY', '¥', 'Chinese Yuan'),
  CurrencyInfo('INR', '₹', 'Indian Rupee'),
  CurrencyInfo('KRW', '₩', 'South Korean Won'),
  CurrencyInfo('IDR', 'Rp', 'Indonesian Rupiah'),
  CurrencyInfo('MYR', 'RM', 'Malaysian Ringgit'),
  CurrencyInfo('SGD', r'S$', 'Singapore Dollar'),
  CurrencyInfo('THB', '฿', 'Thai Baht'),
  CurrencyInfo('VND', '₫', 'Vietnamese Dong'),
  CurrencyInfo('PHP', '₱', 'Philippine Peso'),
  CurrencyInfo('PKR', 'Rs', 'Pakistani Rupee'),
  CurrencyInfo('BDT', '৳', 'Bangladeshi Taka'),
  CurrencyInfo('LKR', 'Rs', 'Sri Lankan Rupee'),
  CurrencyInfo('NPR', 'Rs', 'Nepali Rupee'),
  CurrencyInfo('MMK', 'K', 'Myanmar Kyat'),
  CurrencyInfo('TWD', r'NT$', 'Taiwan Dollar'),
  CurrencyInfo('HKD', r'HK$', 'Hong Kong Dollar'),
  CurrencyInfo('ILS', '₪', 'Israeli Shekel'),
  CurrencyInfo('TRY', '₺', 'Turkish Lira'),
  CurrencyInfo('CHF', 'Fr', 'Swiss Franc'),
  CurrencyInfo('SEK', 'kr', 'Swedish Krona'),
  CurrencyInfo('NOK', 'kr', 'Norwegian Krone'),
  CurrencyInfo('DKK', 'kr', 'Danish Krone'),
  CurrencyInfo('PLN', 'zł', 'Polish Zloty'),
  CurrencyInfo('CZK', 'Kč', 'Czech Koruna'),
  CurrencyInfo('HUF', 'Ft', 'Hungarian Forint'),
  CurrencyInfo('RON', 'lei', 'Romanian Leu'),
  CurrencyInfo('BGN', 'лв', 'Bulgarian Lev'),
  CurrencyInfo('RUB', '₽', 'Russian Ruble'),
  CurrencyInfo('UAH', '₴', 'Ukrainian Hryvnia'),
  CurrencyInfo('GEL', '₾', 'Georgian Lari'),
];

CurrencyInfo currencyInfo(String code) =>
    kCurrencies.firstWhere((c) => c.code == code, orElse: () => kCurrencies.first);

final Map<String, NumberFormat> _numberFormatCache = {};

String formatAmount(double amount, String code, {int decimalDigits = 2}) {
  final info = currencyInfo(code);
  final key = '${code}_$decimalDigits';
  final fmt = _numberFormatCache.putIfAbsent(
    key,
    () => NumberFormat.currency(
      symbol: '${info.symbol} ',
      decimalDigits: decimalDigits,
    ),
  );
  return fmt.format(amount);
}

class CurrencyService extends ChangeNotifier {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  static const _prefCurrencyKey = 'app_currency_code';

  String get _scopedCurrencyKey {
    final orgId = CompanyService().activeOrganizationId;
    if (orgId.isEmpty || orgId == 'default') {
      return _prefCurrencyKey;
    }
    return '${_prefCurrencyKey}_$orgId';
  }

  final ExchangeRateService _erService = ExchangeRateService();

  String _currency = 'EGP';
  Map<String, double> _exchangeRates = Map<String, double>.from(ExchangeRateService.fallbackRates);
  bool _ratesLoaded = false;
  bool _ratesFetching = false;
  DateTime? _ratesLastFetched;

  String get currency => _currency;
  CurrencyInfo get info => currencyInfo(_currency);
  String get symbol => info.symbol;
  Map<String, double> get exchangeRates => _exchangeRates;
  bool get ratesLoaded => _ratesLoaded;
  bool get ratesFetching => _ratesFetching;
  DateTime? get ratesLastFetched => _ratesLastFetched;

  String format(double amount, {int decimalDigits = 2}) =>
      formatAmount(amount, _currency, decimalDigits: decimalDigits);

  String formatNumber(double amount, {int decimalDigits = 2}) {
    final pattern = decimalDigits == 0 ? '#,##0' : '#,##0.${'0' * decimalDigits}';
    return NumberFormat(pattern, 'en_US').format(amount);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currency = prefs.getString(_scopedCurrencyKey) ?? prefs.getString(_prefCurrencyKey) ?? 'EGP';
    final cached = await _erService.getCached();
    if (cached != null && cached.isNotEmpty) {
      _exchangeRates = cached;
      _ratesLoaded = true;
      _ratesLastFetched = await _erService.lastFetchedAt();
    }
    notifyListeners();
  }

  Future<void> reloadForActiveOrganization() async {
    final prefs = await SharedPreferences.getInstance();
    _currency = prefs.getString(_scopedCurrencyKey) ?? 'EGP';
    notifyListeners();
  }

  Future<void> loadRates({bool forceNetwork = false}) async {
    _ratesFetching = true;
    notifyListeners();

    if (forceNetwork) {
      final fresh = await _erService.forceRefresh();
      if (fresh != null && fresh.isNotEmpty) {
        _exchangeRates = fresh;
        _ratesLoaded = true;
        _ratesLastFetched = await _erService.lastFetchedAt();
      }
      _ratesFetching = false;
      notifyListeners();
      return;
    }

    final cached = await _erService.getCached();
    if (cached != null && cached.isNotEmpty) {
      _exchangeRates = cached;
      _ratesLoaded = true;
      _ratesLastFetched = await _erService.lastFetchedAt();
      notifyListeners();
    }

    final shouldFetch = await _erService.shouldAttemptFetch();
    if (shouldFetch) {
      final fresh = await _erService.forceRefresh();
      if (fresh != null && fresh.isNotEmpty) {
        _exchangeRates = fresh;
        _ratesLoaded = true;
        _ratesLastFetched = await _erService.lastFetchedAt();
      }
    }
    _ratesFetching = false;
    notifyListeners();
  }

  Future<void> refreshRates() => loadRates(forceNetwork: true);

  double? convertBetween(double amount, String from, String to) {
    return _erService.convert(amount, from, to, _exchangeRates);
  }

  Future<void> setCurrency(String code) async {
    if (code.trim().isEmpty || code == _currency) {
      return;
    }
    _currency = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedCurrencyKey, _currency);
    notifyListeners();
  }
}

Future<String?> showCurrencyPicker(BuildContext context, {String? current}) async {
  final ctrl = TextEditingController();
  String query = '';
  const popular = ['USD', 'EUR', 'EGP', 'GBP', 'SAR', 'AED'];

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        final filtered = kCurrencies.where((c) {
          if (query.isEmpty) {
            return true;
          }
          return c.code.toLowerCase().contains(query) ||
              c.name.toLowerCase().contains(query) ||
              c.symbol.toLowerCase().contains(query);
        }).toList();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Select Currency', style: TextStyle(fontWeight: FontWeight.w800)),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    hintText: 'Search by code or name',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                  ),
                  onChanged: (v) => setS(() => query = v.trim().toLowerCase()),
                ),
                if (query.isEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: popular.map((code) {
                      final selected = current == code;
                      return ChoiceChip(
                        label: Text(code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        selected: selected,
                        onSelected: (_) => Navigator.pop(ctx, code),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  height: 320,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final cur = filtered[index];
                      final isSelected = current == cur.code;
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: SizedBox(
                          width: 40,
                          child: Text(
                            cur.symbol,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: isSelected ? cs.primary : cs.onSurface,
                            ),
                          ),
                        ),
                        title: Text(
                          '${cur.code} — ${cur.name}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                        trailing: isSelected ? Icon(Icons.check_circle_rounded, color: cs.primary, size: 18) : null,
                        selected: isSelected,
                        onTap: () => Navigator.pop(ctx, cur.code),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    ),
  );
  Future.delayed(const Duration(milliseconds: 350), ctrl.dispose);
  return result;
}
