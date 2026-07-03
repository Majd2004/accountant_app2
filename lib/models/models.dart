// ==================== ENUMS ====================

enum AccountCategory { asset, liability, equity, revenue, expense }

extension AccountCategoryAr on AccountCategory {
  String get nameAr {
    switch (this) {
      case AccountCategory.asset: return 'أصول';
      case AccountCategory.liability: return 'خصوم';
      case AccountCategory.equity: return 'حقوق ملكية';
      case AccountCategory.revenue: return 'إيرادات';
      case AccountCategory.expense: return 'مصروفات';
    }
  }
  // الحسابات التي رصيدها الطبيعي مدين (أصول ومصروفات)، والباقي رصيدها الطبيعي دائن
  bool get isDebitNormal => this == AccountCategory.asset || this == AccountCategory.expense;
}

enum MovementType { incoming, outgoing, adjustment, damage, loss }

extension MovementTypeAr on MovementType {
  String get nameAr {
    switch (this) {
      case MovementType.incoming: return 'وارد';
      case MovementType.outgoing: return 'صادر';
      case MovementType.adjustment: return 'تسوية (جرد)';
      case MovementType.damage: return 'تالف';
      case MovementType.loss: return 'فاقد';
    }
  }
}

// ==================== MODELS ====================

class Account {
  final int? id;
  String name;
  String type;
  AccountCategory category;
  double balance;
  String currencyCode;
  String? parentId;
  String? notes;
  final String? createdAt;

  Account({
    this.id,
    required this.name,
    required this.type,
    required this.category,
    this.balance = 0,
    this.currencyCode = 'IQD',
    this.parentId,
    this.notes,
    this.createdAt,
  });

  factory Account.fromMap(Map<String, dynamic> m) => Account(
    id: m['id'],
    name: m['name'],
    type: m['type'] ?? '',
    category: AccountCategory.values.firstWhere(
      (e) => e.name == (m['category'] ?? 'asset'),
      orElse: () => AccountCategory.asset,
    ),
    balance: (m['balance'] ?? 0).toDouble(),
    currencyCode: m['currency_code'] ?? 'IQD',
    parentId: m['parent_id']?.toString(),
    notes: m['notes'],
    createdAt: m['created_at'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'type': type,
    'category': category.name,
    'balance': balance,
    'currency_code': currencyCode,
    'parent_id': parentId,
    'notes': notes,
    'created_at': createdAt ?? DateTime.now().toIso8601String(),
  };
}

class JournalEntry {
  final int? id;
  String date;
  String description;
  String? reference;
  String? entryType;
  int? relatedInvoiceId;
  List<JournalLine> lines;
  final String? createdAt;
  String? updatedAt;

  JournalEntry({
    this.id,
    required this.date,
    required this.description,
    this.reference,
    this.entryType,
    this.relatedInvoiceId,
    this.lines = const [],
    this.createdAt,
    this.updatedAt,
  });

  // ملاحظة: هذا مجموع أولي بالأرقام كما أُدخلت (بدون تحويل عملة).
  // التحقق الرسمي من توازن القيد يتم داخل قاعدة البيانات بعملة الأساس،
  // لأن كل سطر قد يخص حساباً بعملة مختلفة.
  double get totalDebit => lines.fold(0, (s, l) => s + l.debit);
  double get totalCredit => lines.fold(0, (s, l) => s + l.credit);
  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.01;

  factory JournalEntry.fromMap(Map<String, dynamic> m) => JournalEntry(
    id: m['id'],
    date: m['date'],
    description: m['description'] ?? '',
    reference: m['reference'],
    entryType: m['entry_type'],
    relatedInvoiceId: m['related_invoice_id'],
    createdAt: m['created_at'],
    updatedAt: m['updated_at'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'date': date,
    'description': description,
    'reference': reference,
    'entry_type': entryType,
    'related_invoice_id': relatedInvoiceId,
    'created_at': createdAt ?? DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };
}

class JournalLine {
  final int? id;
  final int? journalEntryId;
  int accountId;
  String accountName;
  double debit;
  double credit;
  String currencyCode;
  double exchangeRate;
  double debitBase;
  double creditBase;
  String? notes;

  JournalLine({
    this.id,
    this.journalEntryId,
    required this.accountId,
    this.accountName = '',
    this.debit = 0,
    this.credit = 0,
    this.currencyCode = 'IQD',
    this.exchangeRate = 1,
    this.debitBase = 0,
    this.creditBase = 0,
    this.notes,
  });

  factory JournalLine.fromMap(Map<String, dynamic> m) => JournalLine(
    id: m['id'],
    journalEntryId: m['journal_entry_id'],
    accountId: m['account_id'],
    accountName: m['account_name'] ?? '',
    debit: (m['debit'] ?? 0).toDouble(),
    credit: (m['credit'] ?? 0).toDouble(),
    currencyCode: m['currency_code'] ?? 'IQD',
    exchangeRate: (m['exchange_rate'] ?? 1).toDouble(),
    debitBase: (m['debit_base'] ?? 0).toDouble(),
    creditBase: (m['credit_base'] ?? 0).toDouble(),
    notes: m['notes'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    if (journalEntryId != null) 'journal_entry_id': journalEntryId,
    'account_id': accountId,
    'debit': debit,
    'credit': credit,
    'currency_code': currencyCode,
    'exchange_rate': exchangeRate,
    'debit_base': debitBase,
    'credit_base': creditBase,
    'notes': notes,
  };
}

class Product {
  final int? id;
  String name;
  String? code;
  String? category;
  String unit;
  double purchasePrice; // آخر/مرجعي سعر شراء يقترحه النظام فقط
  double averageCost; // التكلفة المرجّحة الفعلية (تُحسب تلقائياً، غير قابلة للتعديل المباشر)
  double salePrice;
  double quantity; // تُحسب تلقائياً من حركات المخزن
  double minQuantity;
  int? warehouseId;
  String? warehouseName;
  String? notes;

  Product({
    this.id,
    required this.name,
    this.code,
    this.category,
    this.unit = 'قطعة',
    this.purchasePrice = 0,
    this.averageCost = 0,
    this.salePrice = 0,
    this.quantity = 0,
    this.minQuantity = 0,
    this.warehouseId,
    this.warehouseName,
    this.notes,
  });

  bool get isLowStock => quantity <= minQuantity && minQuantity > 0;

  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'],
    name: m['name'],
    code: m['code'],
    category: m['category'],
    unit: m['unit'] ?? 'قطعة',
    purchasePrice: (m['purchase_price'] ?? 0).toDouble(),
    averageCost: (m['average_cost'] ?? 0).toDouble(),
    salePrice: (m['sale_price'] ?? 0).toDouble(),
    quantity: (m['quantity'] ?? 0).toDouble(),
    minQuantity: (m['min_quantity'] ?? 0).toDouble(),
    warehouseId: m['warehouse_id'],
    warehouseName: m['warehouse_name'],
    notes: m['notes'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'code': code,
    'category': category,
    'unit': unit,
    'purchase_price': purchasePrice,
    'average_cost': averageCost,
    'sale_price': salePrice,
    'quantity': quantity,
    'min_quantity': minQuantity,
    'warehouse_id': warehouseId,
    'notes': notes,
  };
}

class Warehouse {
  final int? id;
  String name;
  String? location;
  String? notes;

  Warehouse({this.id, required this.name, this.location, this.notes});

  factory Warehouse.fromMap(Map<String, dynamic> m) => Warehouse(
    id: m['id'], name: m['name'], location: m['location'], notes: m['notes'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name, 'location': location, 'notes': notes,
  };
}

class WarehouseMovement {
  final int? id;
  final int productId;
  String productName;
  final int? warehouseId;
  String warehouseName;
  MovementType movementType;
  double quantity;
  double unitPrice;
  String date;
  String? reason;
  String? reference;
  int? invoiceId;
  String? notes;
  final String? createdAt;

  WarehouseMovement({
    this.id,
    required this.productId,
    this.productName = '',
    this.warehouseId,
    this.warehouseName = '',
    required this.movementType,
    required this.quantity,
    this.unitPrice = 0,
    required this.date,
    this.reason,
    this.reference,
    this.invoiceId,
    this.notes,
    this.createdAt,
  });

  factory WarehouseMovement.fromMap(Map<String, dynamic> m) => WarehouseMovement(
    id: m['id'],
    productId: m['product_id'],
    productName: m['product_name'] ?? '',
    warehouseId: m['warehouse_id'],
    warehouseName: m['warehouse_name'] ?? '',
    movementType: MovementType.values.firstWhere(
      (e) => e.name == (m['movement_type'] ?? 'incoming'),
      orElse: () => MovementType.incoming,
    ),
    quantity: (m['quantity'] ?? 0).toDouble(),
    unitPrice: (m['unit_price'] ?? 0).toDouble(),
    date: m['date'] ?? '',
    reason: m['reason'],
    reference: m['reference'],
    invoiceId: m['invoice_id'],
    notes: m['notes'],
    createdAt: m['created_at'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'product_id': productId,
    'warehouse_id': warehouseId,
    'movement_type': movementType.name,
    'quantity': quantity,
    'unit_price': unitPrice,
    'date': date,
    'reason': reason,
    'reference': reference,
    'invoice_id': invoiceId,
    'notes': notes,
    'created_at': createdAt ?? DateTime.now().toIso8601String(),
  };
}

class Currency {
  final int? id;
  String name;
  String code;
  String symbol;
  double exchangeRate;
  bool isDefault;

  Currency({
    this.id,
    required this.name,
    required this.code,
    this.symbol = '',
    this.exchangeRate = 1,
    this.isDefault = false,
  });

  factory Currency.fromMap(Map<String, dynamic> m) => Currency(
    id: m['id'],
    name: m['name'],
    code: m['code'],
    symbol: m['symbol'] ?? '',
    exchangeRate: (m['exchange_rate'] ?? 1).toDouble(),
    isDefault: (m['is_default'] ?? 0) == 1,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'code': code,
    'symbol': symbol,
    'exchange_rate': exchangeRate,
    'is_default': isDefault ? 1 : 0,
  };
}

class CurrencyRateHistory {
  final int? id;
  final int currencyId;
  final double oldRate;
  final double newRate;
  final String changedAt;
  final String? notes;

  CurrencyRateHistory({
    this.id,
    required this.currencyId,
    required this.oldRate,
    required this.newRate,
    required this.changedAt,
    this.notes,
  });

  factory CurrencyRateHistory.fromMap(Map<String, dynamic> m) => CurrencyRateHistory(
    id: m['id'],
    currencyId: m['currency_id'],
    oldRate: (m['old_rate'] ?? 0).toDouble(),
    newRate: (m['new_rate'] ?? 0).toDouble(),
    changedAt: m['changed_at'] ?? '',
    notes: m['notes'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'currency_id': currencyId,
    'old_rate': oldRate,
    'new_rate': newRate,
    'changed_at': changedAt,
    'notes': notes,
  };
}

class Invoice {
  final int? id;
  String invoiceNumber;
  String date;
  String type; // بيع | شراء | مرتجع بيع | مرتجع شراء
  int? accountId; // حساب العميل/المورد
  String? accountName;
  int? cashAccountId; // حساب الصندوق/البنك المستخدم للجزء المدفوع
  String? cashAccountName;
  int? warehouseId;
  double subtotal;
  double discount;
  double tax;
  double total;
  double paid;
  double remaining;
  String currencyCode;
  String? notes;
  List<InvoiceItem> items;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.date,
    required this.type,
    this.accountId,
    this.accountName,
    this.cashAccountId,
    this.cashAccountName,
    this.warehouseId,
    this.subtotal = 0,
    this.discount = 0,
    this.tax = 0,
    this.total = 0,
    this.paid = 0,
    this.remaining = 0,
    this.currencyCode = 'IQD',
    this.notes,
    this.items = const [],
  });

  factory Invoice.fromMap(Map<String, dynamic> m) => Invoice(
    id: m['id'],
    invoiceNumber: m['invoice_number'] ?? '',
    date: m['date'] ?? '',
    type: m['type'] ?? 'بيع',
    accountId: m['account_id'],
    accountName: m['account_name'],
    cashAccountId: m['cash_account_id'],
    cashAccountName: m['cash_account_name'],
    warehouseId: m['warehouse_id'],
    subtotal: (m['subtotal'] ?? 0).toDouble(),
    discount: (m['discount'] ?? 0).toDouble(),
    tax: (m['tax'] ?? 0).toDouble(),
    total: (m['total'] ?? 0).toDouble(),
    paid: (m['paid'] ?? 0).toDouble(),
    remaining: (m['remaining'] ?? 0).toDouble(),
    currencyCode: m['currency_code'] ?? 'IQD',
    notes: m['notes'],
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'invoice_number': invoiceNumber,
    'date': date,
    'type': type,
    'account_id': accountId,
    'cash_account_id': cashAccountId,
    'warehouse_id': warehouseId,
    'subtotal': subtotal,
    'discount': discount,
    'tax': tax,
    'total': total,
    'paid': paid,
    'remaining': remaining,
    'currency_code': currencyCode,
    'notes': notes,
  };
}

class InvoiceItem {
  final int? id;
  final int? invoiceId;
  int productId;
  String productName;
  double quantity;
  double unitPrice;
  double discount;
  double total;
  String unit;

  InvoiceItem({
    this.id,
    this.invoiceId,
    required this.productId,
    this.productName = '',
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    required this.total,
    this.unit = 'قطعة',
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> m) => InvoiceItem(
    id: m['id'],
    invoiceId: m['invoice_id'],
    productId: m['product_id'],
    productName: m['product_name'] ?? '',
    quantity: (m['quantity'] ?? 0).toDouble(),
    unitPrice: (m['unit_price'] ?? 0).toDouble(),
    discount: (m['discount'] ?? 0).toDouble(),
    total: (m['total'] ?? 0).toDouble(),
    unit: m['unit'] ?? 'قطعة',
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    if (invoiceId != null) 'invoice_id': invoiceId,
    'product_id': productId,
    'quantity': quantity,
    'unit_price': unitPrice,
    'discount': discount,
    'total': total,
    'unit': unit,
  };
}

class AuditLog {
  final int? id;
  final String tableName;
  final int? recordId;
  final String action; // INSERT | UPDATE | DELETE
  final String? oldValues;
  final String? newValues;
  final String createdAt;

  AuditLog({
    this.id,
    required this.tableName,
    this.recordId,
    required this.action,
    this.oldValues,
    this.newValues,
    required this.createdAt,
  });

  factory AuditLog.fromMap(Map<String, dynamic> m) => AuditLog(
    id: m['id'],
    tableName: m['table_name'],
    recordId: m['record_id'],
    action: m['action'],
    oldValues: m['old_values'],
    newValues: m['new_values'],
    createdAt: m['created_at'],
  );
}
