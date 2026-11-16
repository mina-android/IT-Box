import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:itbox/services/exchange_rate_service.dart';
import 'package:itbox/services/currency_service.dart';
import 'package:itbox/services/company_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExchangeRateService & CurrencyService', () {
    test('convert uses USD pivot and fallbackRates when offline', () {
      final er = ExchangeRateService();
      final rates = ExchangeRateService.fallbackRates;

      expect(er.convert(100.0, 'USD', 'USD', rates), 100.0);

      final usdToEgp = er.convert(10.0, 'USD', 'EGP', rates);
      expect(usdToEgp, closeTo(505.0, 0.01));

      final egpToEur = er.convert(505.0, 'EGP', 'EUR', rates);
      expect(egpToEur, closeTo(9.2, 0.01));
    });

    test('CurrencyService loads and persists selected currency', () async {
      SharedPreferences.setMockInitialValues({});
      final cs = CurrencyService();
      await cs.load();
      expect(cs.currency, 'EGP');

      await cs.setCurrency('USD');
      expect(cs.currency, 'USD');
      expect(cs.symbol, r'$');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_currency_code'), 'USD');
    });
  });

  group('CompanyService Multi-Organization Isolation', () {
    test('migrates legacy company_name into default org with itbox.db', () async {
      SharedPreferences.setMockInitialValues({
        'company_name': 'Acme HQ',
        'onboarding_done': true,
      });
      final company = CompanyService();
      await company.load();

      expect(company.organizations.length, 1);
      expect(company.activeOrganization.id, 'default');
      expect(company.activeOrganization.name, 'Acme HQ');
      expect(company.activeOrganization.dbFileName, 'itbox.db');
    });

    test('creates new organization with isolated dbFileName without losing default', () async {
      SharedPreferences.setMockInitialValues({
        'company_name': 'Acme HQ',
        'onboarding_done': true,
      });
      final company = CompanyService();
      await company.load();

      final branch = await company.createOrganization(
        name: 'Alexandria Branch',
        switchImmediately: false,
      );

      expect(company.organizations.length, 2);
      expect(branch.name, 'Alexandria Branch');
      expect(branch.dbFileName, startsWith('itbox_org_'));
      expect(branch.dbFileName, endsWith('.db'));
      expect(company.activeOrganization.id, 'default');
    });

    test('deleteOrganization prevents deleting default and removes secondary orgs', () async {
      SharedPreferences.setMockInitialValues({
        'company_name': 'Acme HQ',
        'onboarding_done': true,
      });
      final company = CompanyService();
      await company.load();

      expect(await company.deleteOrganization('default'), isFalse);

      final branch = await company.createOrganization(
        name: 'Branch To Delete',
        switchImmediately: false,
      );
      expect(company.organizations.length, 2);

      final deleted = await company.deleteOrganization(branch.id);
      expect(deleted, isTrue);
      expect(company.organizations.length, 1);
      expect(company.activeOrganization.id, 'default');
    });
  });
}
