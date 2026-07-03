import 'package:flutter/material.dart';
import '../models/models.dart';

class AppTheme {
  static const primary = Color(0xFF1565C0);
  static const secondary = Color(0xFF00897B);
  static const background = Color(0xFFF0F4F8);
  static const surface = Colors.white;
  static const error = Color(0xFFD32F2F);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF57F17);

  static const cardRadius = 14.0;
  static const inputRadius = 10.0;

  static ThemeData get theme => ThemeData(
    fontFamily: 'Cairo',
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: error,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
      color: surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: const TextStyle(fontFamily: 'Cairo'),
      hintStyle: TextStyle(fontFamily: 'Cairo', color: Colors.grey[400]),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    dividerTheme: DividerThemeData(color: Colors.grey[200], thickness: 1),
  );
}

// ==================== SHARED WIDGETS ====================

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final IconData? icon;
  const InfoCard({super.key, required this.label, required this.value, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (icon != null) ...[Icon(icon, size: 18, color: c), const SizedBox(width: 6)],
              Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 16), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// نتيجة عرض رصيد حساب: هل هو على الجهة الطبيعية له (مدين لحساب أصول، دائن لحساب
// خصوم مثلاً) أم على جهة غير معتادة (يستحق الانتباه لكن ليس بالضرورة خطأ).
class AccountBalanceDisplay {
  final String label;
  final double amount;
  final bool isNormal;
  AccountBalanceDisplay(this.label, this.amount, this.isNormal);
}

AccountBalanceDisplay accountDisplayBalance(Account a) {
  final isDebitNormalCategory = a.category.isDebitNormal;
  final isDebitSide = a.balance >= 0;
  final label = isDebitSide ? 'مدين' : 'دائن';
  final isNormal = isDebitSide == isDebitNormalCategory;
  return AccountBalanceDisplay(label, a.balance.abs(), isNormal);
}

// تنسيق مبلغ بفواصل الآلاف بدون أي اختصار أو تقريب مضلل - مهم لتطبيق محاسبي
// حيث الدقة الكاملة للأرقام أهم من الاختصار الجمالي.
String formatAmount(double amount, {String symbol = 'د.ع', bool showSign = false}) {
  final isNeg = amount < 0;
  final abs = amount.abs();
  final rounded = double.parse(abs.toStringAsFixed(2));
  final truncated = rounded.truncate();
  final hasFraction = (rounded - truncated).abs() > 0.001;

  final intStr = truncated.toString();
  final buf = StringBuffer();
  for (int i = 0; i < intStr.length; i++) {
    if (i > 0 && (intStr.length - i) % 3 == 0) buf.write(',');
    buf.write(intStr[i]);
  }
  var result = buf.toString();
  if (hasFraction) {
    final fracDigits = ((rounded - truncated) * 100).round().toString().padLeft(2, '0');
    result = '$result.$fracDigits';
  }
  final sign = isNeg ? '-' : '';
  return symbol.isEmpty ? '$sign$result' : '$sign$result $symbol';
}

String formatDate(String isoDate) {
  try {
    final d = DateTime.parse(isoDate);
    return '${d.year}/${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}';
  } catch (_) {
    return isoDate;
  }
}
