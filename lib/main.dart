import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/accounts_screen.dart';
import 'screens/journal_entries_screen.dart';
import 'screens/voucher_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/invoice_screen.dart';
import 'screens/products_screen.dart';
import 'screens/warehouses_screen.dart';
import 'screens/currency_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/backup_screen.dart';
import 'screens/statement_screen.dart';
import 'screens/search_screen.dart';
import 'screens/reports_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppTheme.primary,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const AccountingApp());
}

class AccountingApp extends StatelessWidget {
  const AccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'المحاسب الشامل',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: const Locale('ar', 'IQ'),
      initialRoute: '/',
      routes: {
        '/': (c) => const HomeScreen(),
        '/accounts': (c) => const AccountsScreen(),
        '/journal': (c) => const JournalEntriesScreen(),
        '/voucher': (c) => const VoucherScreen(),
        '/transfer': (c) => const TransferScreen(),
        '/invoice': (c) => const InvoiceScreen(),
        '/products': (c) => const ProductsScreen(),
        '/warehouses': (c) => const WarehousesScreen(),
        '/currencies': (c) => const CurrencyScreen(),
        '/settings': (c) => const SettingsScreen(),
        '/backup': (c) => const BackupScreen(),
        '/statement': (c) => const StatementScreen(),
        '/search': (c) => const SearchScreen(),
        '/reports': (c) => const ReportsScreen(),
      },
    );
  }
}
