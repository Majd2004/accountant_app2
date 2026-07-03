import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;
  DatabaseHelper._();

  Future<Database> get database async => _db ??= await _init();

  Future<Database> _init() async {
    // اسم قاعدة بيانات جديد (v3) عمداً: هيكل الجداول تغيّر جذرياً (عملات متعددة،
    // تكلفة مرجّحة، ربط الفواتير بالقيود)، فقاعدة بيانات V2 القديمة غير متوافقة.
    // بيانات التجربة السابقة لن تُنقل تلقائياً.
    final path = join(await getDatabasesPath(), 'accounting_v3.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int v) async {
    await db.execute('''CREATE TABLE accounts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'asset',
      balance REAL DEFAULT 0,
      currency_code TEXT DEFAULT 'IQD',
      parent_id INTEGER,
      notes TEXT,
      created_at TEXT
    )''');

    await db.execute('''CREATE TABLE journal_entries(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      description TEXT NOT NULL,
      reference TEXT,
      entry_type TEXT,
      related_invoice_id INTEGER,
      created_at TEXT,
      updated_at TEXT
    )''');

    await db.execute('''CREATE TABLE journal_lines(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      journal_entry_id INTEGER NOT NULL,
      account_id INTEGER NOT NULL,
      currency_code TEXT DEFAULT 'IQD',
      exchange_rate REAL DEFAULT 1,
      debit REAL DEFAULT 0,
      credit REAL DEFAULT 0,
      debit_base REAL DEFAULT 0,
      credit_base REAL DEFAULT 0,
      notes TEXT,
      FOREIGN KEY(journal_entry_id) REFERENCES journal_entries(id),
      FOREIGN KEY(account_id) REFERENCES accounts(id)
    )''');

    await db.execute('''CREATE TABLE products(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      code TEXT,
      category TEXT,
      unit TEXT DEFAULT 'قطعة',
      purchase_price REAL DEFAULT 0,
      average_cost REAL DEFAULT 0,
      sale_price REAL DEFAULT 0,
      quantity REAL DEFAULT 0,
      min_quantity REAL DEFAULT 0,
      warehouse_id INTEGER,
      notes TEXT
    )''');

    await db.execute('''CREATE TABLE warehouses(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      location TEXT,
      notes TEXT
    )''');

    await db.execute('''CREATE TABLE warehouse_movements(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      warehouse_id INTEGER,
      movement_type TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_price REAL DEFAULT 0,
      date TEXT NOT NULL,
      reason TEXT,
      reference TEXT,
      invoice_id INTEGER,
      notes TEXT,
      created_at TEXT,
      FOREIGN KEY(product_id) REFERENCES products(id),
      FOREIGN KEY(warehouse_id) REFERENCES warehouses(id)
    )''');

    await db.execute('''CREATE TABLE invoices(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_number TEXT NOT NULL,
      date TEXT NOT NULL,
      type TEXT NOT NULL,
      account_id INTEGER,
      cash_account_id INTEGER,
      warehouse_id INTEGER,
      subtotal REAL DEFAULT 0,
      discount REAL DEFAULT 0,
      tax REAL DEFAULT 0,
      total REAL DEFAULT 0,
      paid REAL DEFAULT 0,
      remaining REAL DEFAULT 0,
      currency_code TEXT DEFAULT 'IQD',
      notes TEXT
    )''');

    await db.execute('''CREATE TABLE invoice_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT,
      quantity REAL NOT NULL,
      unit_price REAL NOT NULL,
      discount REAL DEFAULT 0,
      total REAL NOT NULL,
      unit TEXT DEFAULT 'قطعة',
      FOREIGN KEY(invoice_id) REFERENCES invoices(id)
    )''');

    await db.execute('''CREATE TABLE currencies(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      code TEXT NOT NULL UNIQUE,
      symbol TEXT DEFAULT '',
      exchange_rate REAL DEFAULT 1,
      is_default INTEGER DEFAULT 0
    )''');

    await db.execute('''CREATE TABLE currency_rate_history(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      currency_id INTEGER NOT NULL,
      old_rate REAL NOT NULL,
      new_rate REAL NOT NULL,
      changed_at TEXT NOT NULL,
      notes TEXT,
      FOREIGN KEY(currency_id) REFERENCES currencies(id)
    )''');

    await db.execute('''CREATE TABLE settings(
      key TEXT PRIMARY KEY,
      value TEXT
    )''');

    await db.execute('''CREATE TABLE audit_log(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      table_name TEXT NOT NULL,
      record_id INTEGER,
      action TEXT NOT NULL,
      old_values TEXT,
      new_values TEXT,
      created_at TEXT NOT NULL
    )''');

    await _seedData(db);
  }

  Future<void> _seedData(Database db) async {
    await db.insert('currencies', {'name': 'دينار عراقي', 'code': 'IQD', 'symbol': 'د.ع', 'exchange_rate': 1, 'is_default': 1});
    await db.insert('currencies', {'name': 'دولار أمريكي', 'code': 'USD', 'symbol': '\$', 'exchange_rate': 1310, 'is_default': 0});

    await db.insert('settings', {'key': 'default_currency', 'value': 'IQD'});
    await db.insert('settings', {'key': 'company_name', 'value': 'شركتي'});

    await db.insert('warehouses', {'name': 'المخزن الرئيسي', 'location': '', 'notes': ''});

    final accounts = [
      {'name': 'الصندوق الرئيسي', 'type': 'صندوق', 'category': 'asset'},
      {'name': 'البنك', 'type': 'بنك', 'category': 'asset'},
      {'name': 'المخزون', 'type': 'مخزون', 'category': 'asset'},
      {'name': 'أرصدة افتتاحية', 'type': 'افتتاحي', 'category': 'equity'},
      {'name': 'رأس المال', 'type': 'رأس مال', 'category': 'equity'},
      {'name': 'إيرادات المبيعات', 'type': 'إيراد', 'category': 'revenue'},
      {'name': 'ضريبة المبيعات المستحقة', 'type': 'ضريبة', 'category': 'liability'},
      {'name': 'تكلفة البضاعة المباعة', 'type': 'تكلفة', 'category': 'expense'},
      {'name': 'المصروفات العمومية', 'type': 'مصروف', 'category': 'expense'},
      {'name': 'رواتب الموظفين', 'type': 'موظف', 'category': 'expense'},
    ];
    for (var a in accounts) {
      await db.insert('accounts', {...a, 'balance': 0.0, 'currency_code': 'IQD', 'created_at': DateTime.now().toIso8601String()});
    }
  }

  // ==================== AUDIT LOG ====================
  Future<void> _log(DatabaseExecutor db, String table, int? id, String action, {Map? old_, Map? new_}) async {
    await db.insert('audit_log', {
      'table_name': table,
      'record_id': id,
      'action': action,
      'old_values': old_ != null ? jsonEncode(old_) : null,
      'new_values': new_ != null ? jsonEncode(new_) : null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLog({int limit = 100}) async {
    final db = await database;
    return db.query('audit_log', orderBy: 'created_at DESC', limit: limit);
  }

  // ==================== SETTINGS ====================
  Future<String?> getSetting(String key) async {
    final db = await database;
    final r = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return r.isNotEmpty ? r.first['value'] as String? : null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ==================== CURRENCIES ====================
  Future<List<Currency>> getCurrencies() async {
    final db = await database;
    final rows = await db.query('currencies', orderBy: 'is_default DESC, name');
    return rows.map(Currency.fromMap).toList();
  }

  Future<Currency?> getDefaultCurrency() async {
    final db = await database;
    final r = await db.query('currencies', where: 'is_default = 1', limit: 1);
    return r.isNotEmpty ? Currency.fromMap(r.first) : null;
  }

  Future<int> insertCurrency(Currency c) async {
    final db = await database;
    final id = await db.insert('currencies', c.toMap());
    await _log(db, 'currencies', id, 'INSERT', new_: c.toMap());
    return id;
  }

  Future<void> updateCurrency(Currency c) async {
    final db = await database;
    final old = await db.query('currencies', where: 'id = ?', whereArgs: [c.id]);
    if (old.isNotEmpty) {
      final oldRate = (old.first['exchange_rate'] as num).toDouble();
      if ((oldRate - c.exchangeRate).abs() > 0.0001) {
        await db.insert('currency_rate_history', {
          'currency_id': c.id,
          'old_rate': oldRate,
          'new_rate': c.exchangeRate,
          'changed_at': DateTime.now().toIso8601String(),
        });
      }
    }
    await db.update('currencies', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    await _log(db, 'currencies', c.id, 'UPDATE', old_: old.isNotEmpty ? old.first : null, new_: c.toMap());
  }

  // هل هناك أي قيود مسجلة فعلاً في النظام؟ (تُستخدم لتحذير المستخدم عند تغيير العملة الرئيسية)
  Future<bool> hasAnyTransactions() async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM journal_lines');
    return ((r.first['c'] as int?) ?? 0) > 0;
  }

  // تغيير العملة الرئيسية: يعيد حساب أسعار صرف كل العملات نسبةً للعملة الجديدة
  // حتى تبقى كل الأسعار صحيحة رياضياً. القيود التاريخية لا تتأثر (تبقى كما سُجّلت).
  Future<void> setDefaultCurrency(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final newDefaultRows = await txn.query('currencies', where: 'id = ?', whereArgs: [id]);
      if (newDefaultRows.isEmpty) throw Exception('العملة غير موجودة');
      final newDefaultRate = (newDefaultRows.first['exchange_rate'] as num).toDouble();
      if (newDefaultRate <= 0) throw Exception('سعر صرف هذه العملة غير صالح ليصبح أساساً للتحويل');

      final all = await txn.query('currencies');
      for (var c in all) {
        final oldRate = (c['exchange_rate'] as num).toDouble();
        final newRate = oldRate / newDefaultRate;
        await txn.update('currencies', {'exchange_rate': newRate, 'is_default': (c['id'] == id) ? 1 : 0},
            where: 'id = ?', whereArgs: [c['id']]);
      }
    });
    final r = await db.query('currencies', where: 'id = ?', whereArgs: [id]);
    if (r.isNotEmpty) await setSetting('default_currency', r.first['code'] as String);
  }

  Future<bool> canDeleteCurrency(int id) async {
    final db = await database;
    final cur = await db.query('currencies', where: 'id = ?', whereArgs: [id]);
    if (cur.isEmpty) return false;
    if ((cur.first['is_default'] as int) == 1) return false;
    final code = cur.first['code'] as String;
    final used = await db.rawQuery('SELECT COUNT(*) as c FROM accounts WHERE currency_code = ?', [code]);
    return ((used.first['c'] as int?) ?? 0) == 0;
  }

  Future<void> deleteCurrency(int id) async {
    final db = await database;
    if (!(await canDeleteCurrency(id))) {
      throw Exception('لا يمكن حذف هذه العملة: إما أنها العملة الرئيسية أو أن هناك حسابات تستخدمها');
    }
    final old = await db.query('currencies', where: 'id = ?', whereArgs: [id]);
    await db.delete('currencies', where: 'id = ?', whereArgs: [id]);
    await _log(db, 'currencies', id, 'DELETE', old_: old.isNotEmpty ? old.first : null);
  }

  Future<List<CurrencyRateHistory>> getCurrencyRateHistory(int currencyId) async {
    final db = await database;
    final rows = await db.query('currency_rate_history',
        where: 'currency_id = ?', whereArgs: [currencyId], orderBy: 'changed_at DESC');
    return rows.map(CurrencyRateHistory.fromMap).toList();
  }

  // ==================== JOURNAL LINE PREPARATION (عملة + معادل بعملة الأساس) ====================

  Future<Map<String, dynamic>> _prepareLine(DatabaseExecutor db, JournalLine line) async {
    final debit = line.debit > 0 ? line.debit : 0.0;
    final credit = line.credit > 0 ? line.credit : 0.0;
    final accRows = await db.query('accounts', where: 'id = ?', whereArgs: [line.accountId]);
    if (accRows.isEmpty) throw Exception('حساب غير موجود (رقم ${line.accountId})');
    final currencyCode = accRows.first['currency_code'] as String? ?? 'IQD';
    final curRows = await db.query('currencies', where: 'code = ?', whereArgs: [currencyCode]);
    final rate = curRows.isNotEmpty ? (curRows.first['exchange_rate'] as num).toDouble() : 1.0;
    return {
      'account_id': line.accountId,
      'currency_code': currencyCode,
      'exchange_rate': rate,
      'debit': debit,
      'credit': credit,
      'debit_base': debit * rate,
      'credit_base': credit * rate,
      'notes': line.notes,
    };
  }

  Future<List<Map<String, dynamic>>> _validateAndPrepareLines(DatabaseExecutor db, List<JournalLine> lines) async {
    final prepared = <Map<String, dynamic>>[];
    double totalDebitBase = 0, totalCreditBase = 0;
    for (var line in lines) {
      if (line.debit > 0 && line.credit > 0) {
        throw Exception('لا يمكن أن يحتوي سطر واحد على مبلغ مدين ومبلغ دائن معاً');
      }
      if (line.debit <= 0 && line.credit <= 0) continue;
      final map = await _prepareLine(db, line);
      prepared.add(map);
      totalDebitBase += map['debit_base'] as double;
      totalCreditBase += map['credit_base'] as double;
    }
    if (prepared.length < 2) {
      throw Exception('يجب أن يحتوي القيد على سطرين فعليين على الأقل، كل سطر بحساب وبمبلغ صحيح');
    }
    if ((totalDebitBase - totalCreditBase).abs() > 0.01) {
      throw Exception(
        'القيد غير متوازن بعملة الأساس: إجمالي المدين = ${totalDebitBase.toStringAsFixed(2)}، '
        'إجمالي الدائن = ${totalCreditBase.toStringAsFixed(2)}',
      );
    }
    return prepared;
  }

  Future<List<JournalLine>> _getJournalLines(DatabaseExecutor db, int entryId) async {
    final rows = await db.rawQuery('''
      SELECT jl.*, a.name as account_name 
      FROM journal_lines jl
      LEFT JOIN accounts a ON jl.account_id = a.id
      WHERE jl.journal_entry_id = ?
    ''', [entryId]);
    return rows.map(JournalLine.fromMap).toList();
  }

  // ينشئ حساباً "نظامياً" تلقائياً إذا لم يكن موجوداً (دفاعياً)، لضمان أن الفواتير
  // تجد دائماً حسابات الإيرادات/المخزون/التكلفة حتى لو حذفها المستخدم أو أعاد تسميتها
  Future<int> _getOrCreateSystemAccount(DatabaseExecutor db, String name, String category) async {
    final rows = await db.query('accounts', where: 'name = ?', whereArgs: [name]);
    if (rows.isNotEmpty) return rows.first['id'] as int;
    final defaultCur = await db.query('currencies', where: 'is_default = 1', limit: 1);
    final code = defaultCur.isNotEmpty ? defaultCur.first['code'] as String : 'IQD';
    return await db.insert('accounts', {
      'name': name,
      'type': 'نظام',
      'category': category,
      'balance': 0.0,
      'currency_code': code,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ==================== ACCOUNTS ====================
  Future<List<Account>> getAccounts({String? type, String? category}) async {
    final db = await database;
    String? where;
    List? args;
    if (type != null && category != null) { where = 'type = ? AND category = ?'; args = [type, category]; }
    else if (type != null) { where = 'type = ?'; args = [type]; }
    else if (category != null) { where = 'category = ?'; args = [category]; }
    final rows = await db.query('accounts', where: where, whereArgs: args, orderBy: 'category, name');
    return rows.map(Account.fromMap).toList();
  }

  Future<Account?> getAccount(int id) async {
    final db = await database;
    final r = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    return r.isNotEmpty ? Account.fromMap(r.first) : null;
  }

  Future<int> insertAccount(Account a) async {
    final db = await database;
    final id = await db.insert('accounts', a.toMap());
    await _log(db, 'accounts', id, 'INSERT', new_: a.toMap());
    return id;
  }

  Future<void> updateAccount(Account a) async {
    final db = await database;
    final old = await db.query('accounts', where: 'id = ?', whereArgs: [a.id]);
    await db.update('accounts', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
    await _log(db, 'accounts', a.id, 'UPDATE', old_: old.isNotEmpty ? old.first : null, new_: a.toMap());
  }

  Future<bool> canDeleteAccount(int id) async {
    final db = await database;
    final inJournal = await db.rawQuery('SELECT COUNT(*) as c FROM journal_lines WHERE account_id = ?', [id]);
    return ((inJournal.first['c'] as int?) ?? 0) == 0;
  }

  Future<void> deleteAccount(int id) async {
    final db = await database;
    if (!(await canDeleteAccount(id))) throw Exception('لا يمكن حذف حساب له قيود مسجلة');
    final old = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    await _log(db, 'accounts', id, 'DELETE', old_: old.isNotEmpty ? old.first : null);
  }

  // ==================== JOURNAL ENTRIES ====================
  Future<List<JournalEntry>> getJournalEntries({String? dateFrom, String? dateTo, String? type}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (dateFrom != null) { conditions.add('date >= ?'); args.add(dateFrom); }
    if (dateTo != null) { conditions.add('date <= ?'); args.add(dateTo); }
    if (type != null) { conditions.add('entry_type = ?'); args.add(type); }
    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final rows = await db.query('journal_entries', where: where, whereArgs: args.isNotEmpty ? args : null, orderBy: 'date DESC, id DESC');
    final entries = rows.map(JournalEntry.fromMap).toList();
    for (var e in entries) {
      e.lines = await _getJournalLines(db, e.id!);
    }
    return entries;
  }

  Future<int> _insertJournalEntryTxn(Transaction txn, JournalEntry entry) async {
    final prepared = await _validateAndPrepareLines(txn, entry.lines);
    final id = await txn.insert('journal_entries', entry.toMap());
    for (var map in prepared) {
      await txn.insert('journal_lines', {...map, 'journal_entry_id': id});
      final debit = map['debit'] as double;
      final credit = map['credit'] as double;
      final accountId = map['account_id'] as int;
      if (debit > 0) await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE id = ?', [debit, accountId]);
      if (credit > 0) await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE id = ?', [credit, accountId]);
    }
    await _log(txn, 'journal_entries', id, 'INSERT', new_: entry.toMap());
    return id;
  }

  Future<int> insertJournalEntry(JournalEntry entry) async {
    final db = await database;
    return db.transaction((txn) => _insertJournalEntryTxn(txn, entry));
  }

  Future<void> updateJournalEntry(JournalEntry entry) async {
    final db = await database;
    await db.transaction((txn) async {
      final oldLines = await _getJournalLines(txn, entry.id!);
      for (var line in oldLines) {
        if (line.debit > 0) await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE id = ?', [line.debit, line.accountId]);
        if (line.credit > 0) await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE id = ?', [line.credit, line.accountId]);
      }
      await txn.delete('journal_lines', where: 'journal_entry_id = ?', whereArgs: [entry.id]);

      final prepared = await _validateAndPrepareLines(txn, entry.lines);
      await txn.update('journal_entries', entry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
      for (var map in prepared) {
        await txn.insert('journal_lines', {...map, 'journal_entry_id': entry.id});
        final debit = map['debit'] as double;
        final credit = map['credit'] as double;
        final accountId = map['account_id'] as int;
        if (debit > 0) await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE id = ?', [debit, accountId]);
        if (credit > 0) await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE id = ?', [credit, accountId]);
      }
      await _log(txn, 'journal_entries', entry.id, 'UPDATE', new_: entry.toMap());
    });
  }

  Future<void> deleteJournalEntry(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final lines = await _getJournalLines(txn, id);
      for (var line in lines) {
        if (line.debit > 0) await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE id = ?', [line.debit, line.accountId]);
        if (line.credit > 0) await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE id = ?', [line.credit, line.accountId]);
      }
      await txn.delete('journal_lines', where: 'journal_entry_id = ?', whereArgs: [id]);
      await txn.delete('journal_entries', where: 'id = ?', whereArgs: [id]);
      await _log(txn, 'journal_entries', id, 'DELETE');
    });
  }

  // ==================== WAREHOUSE STOCK ENGINE (تكلفة مرجحة عبر إعادة الحساب الكاملة) ====================

  // يعيد حساب الكمية والتكلفة المرجحة لمنتج معيّن من الصفر بإعادة تشغيل كل حركاته
  // بالترتيب الزمني. هذا أدق من التحديث التراكمي لأنه يصحح نفسه تلقائياً بعد أي
  // تعديل أو حذف أو إضافة حركة بتاريخ سابق، ويمنع وصول المخزون لكمية سالبة.
  Future<void> _recalculateProductStock(DatabaseExecutor txn, int productId) async {
    final movements = await txn.query('warehouse_movements',
        where: 'product_id = ?', whereArgs: [productId], orderBy: 'date ASC, id ASC');
    double qty = 0;
    double avgCost = 0;
    for (var m in movements) {
      final type = m['movement_type'] as String;
      final storedQty = (m['quantity'] as num).toDouble();
      final movId = m['id'] as int;

      if (type == 'incoming') {
        final unitPrice = (m['unit_price'] as num?)?.toDouble() ?? 0;
        final newQty = qty + storedQty;
        avgCost = newQty > 0 ? (((qty * avgCost) + (storedQty * unitPrice)) / newQty) : unitPrice;
        qty = newQty;
      } else if (type == 'adjustment') {
        // قيمة "الكمية" في حركة التسوية تمثل الكمية الفعلية المستهدفة بعد الجرد
        qty = storedQty;
        await txn.update('warehouse_movements', {'unit_price': avgCost}, where: 'id = ?', whereArgs: [movId]);
      } else {
        // صادر / تالف / فاقد: تُقيَّم دائماً بالتكلفة المرجحة الحالية في تلك اللحظة
        qty -= storedQty;
        await txn.update('warehouse_movements', {'unit_price': avgCost}, where: 'id = ?', whereArgs: [movId]);
      }

      if (qty < -0.001) {
        throw Exception('العملية سببها مخزون سالب لهذا المنتج. راجع الحركات المسجلة أو أضف كمية واردة أولاً.');
      }
      if (qty < 0) qty = 0;
    }
    await txn.update('products', {'quantity': qty, 'average_cost': avgCost}, where: 'id = ?', whereArgs: [productId]);
  }

  // ==================== PRODUCTS ====================
  Future<List<Product>> getProducts({int? warehouseId, String? search}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (warehouseId != null) { conditions.add('p.warehouse_id = ?'); args.add(warehouseId); }
    if (search != null && search.isNotEmpty) { conditions.add('(p.name LIKE ? OR p.code LIKE ?)'); args.addAll(['%$search%', '%$search%']); }
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final rows = await db.rawQuery('''
      SELECT p.*, w.name as warehouse_name 
      FROM products p 
      LEFT JOIN warehouses w ON p.warehouse_id = w.id
      $where
      ORDER BY p.name
    ''', args.isNotEmpty ? args : null);
    return rows.map(Product.fromMap).toList();
  }

  Future<int> insertProduct(Product p) async {
    final db = await database;
    return db.transaction((txn) async {
      final map = p.toMap();
      map['quantity'] = 0.0;
      map['average_cost'] = 0.0;
      final id = await txn.insert('products', map);
      if (p.quantity > 0) {
        await txn.insert('warehouse_movements', {
          'product_id': id,
          'warehouse_id': p.warehouseId,
          'movement_type': 'incoming',
          'quantity': p.quantity,
          'unit_price': p.purchasePrice,
          'date': DateTime.now().toIso8601String().substring(0, 10),
          'reason': 'رصيد افتتاحي',
          'created_at': DateTime.now().toIso8601String(),
        });
        await _recalculateProductStock(txn, id);
      }
      await _log(txn, 'products', id, 'INSERT', new_: p.toMap());
      return id;
    });
  }

  // ملاحظة محاسبية مهمة: هذا التحديث لا يغيّر الكمية ولا التكلفة المرجحة أبداً.
  // أي تغيير بالكمية يجب أن يمر عبر حركة مخزن حتى يبقى سجل الحركات مطابقاً
  // للرصيد الفعلي دائماً (بدون "تعديل صامت" يكسر التتبع المحاسبي).
  Future<void> updateProduct(Product p) async {
    final db = await database;
    final old = await db.query('products', where: 'id = ?', whereArgs: [p.id]);
    await db.update('products', {
      'name': p.name,
      'code': p.code,
      'category': p.category,
      'unit': p.unit,
      'purchase_price': p.purchasePrice,
      'sale_price': p.salePrice,
      'min_quantity': p.minQuantity,
      'warehouse_id': p.warehouseId,
      'notes': p.notes,
    }, where: 'id = ?', whereArgs: [p.id]);
    await _log(db, 'products', p.id, 'UPDATE', old_: old.isNotEmpty ? old.first : null, new_: p.toMap());
  }

  Future<bool> canDeleteProduct(int id) async {
    final db = await database;
    final r = await db.rawQuery('SELECT quantity FROM products WHERE id = ?', [id]);
    if (r.isNotEmpty && (r.first['quantity'] as num).toDouble() > 0) return false;
    return true;
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    if (!(await canDeleteProduct(id))) throw Exception('لا يمكن حذف منتج له مخزون. سجّل حركة تالف أو فاقد أولاً لتصفير الكمية.');
    final old = await db.query('products', where: 'id = ?', whereArgs: [id]);
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    await _log(db, 'products', id, 'DELETE', old_: old.isNotEmpty ? old.first : null);
  }

  // ==================== WAREHOUSE MOVEMENTS ====================
  Future<List<WarehouseMovement>> getWarehouseMovements({int? productId, int? warehouseId, String? type}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (productId != null) { conditions.add('wm.product_id = ?'); args.add(productId); }
    if (warehouseId != null) { conditions.add('wm.warehouse_id = ?'); args.add(warehouseId); }
    if (type != null) { conditions.add('wm.movement_type = ?'); args.add(type); }
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final rows = await db.rawQuery('''
      SELECT wm.*, p.name as product_name, w.name as warehouse_name
      FROM warehouse_movements wm
      LEFT JOIN products p ON wm.product_id = p.id
      LEFT JOIN warehouses w ON wm.warehouse_id = w.id
      $where
      ORDER BY wm.date DESC, wm.id DESC
    ''', args.isNotEmpty ? args : null);
    return rows.map(WarehouseMovement.fromMap).toList();
  }

  Future<void> addWarehouseMovement(WarehouseMovement m) async {
    if (m.quantity <= 0) throw Exception('الكمية يجب أن تكون أكبر من صفر');
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('warehouse_movements', m.toMap());
      await _recalculateProductStock(txn, m.productId);
    });
  }

  // حذف حركة يدوية (وليست ناتجة عن فاتورة). محمي: إن كان الحذف سيسبب مخزوناً
  // سالباً في أي نقطة تاريخية، تُرفض العملية تلقائياً برسالة واضحة.
  Future<void> deleteWarehouseMovement(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('warehouse_movements', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return;
      if (rows.first['invoice_id'] != null) {
        throw Exception('هذه الحركة ناتجة عن فاتورة؛ لحذفها احذف الفاتورة نفسها من شاشة الفواتير');
      }
      final productId = rows.first['product_id'] as int;
      final old = rows.first;
      await txn.delete('warehouse_movements', where: 'id = ?', whereArgs: [id]);
      await _recalculateProductStock(txn, productId);
      await _log(txn, 'warehouse_movements', id, 'DELETE', old_: old);
    });
  }

  // ==================== WAREHOUSES ====================
  Future<List<Warehouse>> getWarehouses() async {
    final db = await database;
    final rows = await db.query('warehouses', orderBy: 'name');
    return rows.map(Warehouse.fromMap).toList();
  }

  Future<int> insertWarehouse(Warehouse w) async {
    final db = await database;
    final id = await db.insert('warehouses', w.toMap());
    await _log(db, 'warehouses', id, 'INSERT', new_: w.toMap());
    return id;
  }

  Future<void> updateWarehouse(Warehouse w) async {
    final db = await database;
    await db.update('warehouses', w.toMap(), where: 'id = ?', whereArgs: [w.id]);
    await _log(db, 'warehouses', w.id, 'UPDATE', new_: w.toMap());
  }

  Future<bool> canDeleteWarehouse(int id) async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) as c FROM products WHERE warehouse_id = ? AND quantity > 0', [id]);
    return ((r.first['c'] as int?) ?? 0) == 0;
  }

  Future<void> deleteWarehouse(int id) async {
    final db = await database;
    if (!(await canDeleteWarehouse(id))) throw Exception('لا يمكن حذف مخزن يحتوي على بضاعة');
    await db.delete('warehouses', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== INVOICES (تُنشئ قيداً محاسبياً حقيقياً تلقائياً) ====================

  Future<String> _generateInvoiceNumberTxn(DatabaseExecutor txn, String type) async {
    String prefix;
    if (type == 'بيع') { prefix = 'SAL'; }
    else if (type == 'شراء') { prefix = 'PUR'; }
    else if (type == 'مرتجع بيع') { prefix = 'SRT'; }
    else if (type == 'مرتجع شراء') { prefix = 'PRT'; }
    else { prefix = 'INV'; }
    final year = DateTime.now().year;
    final rows = await txn.rawQuery(
      'SELECT COUNT(*) as c FROM invoices WHERE type = ? AND invoice_number LIKE ?',
      [type, '$prefix-$year-%'],
    );
    final count = (rows.first['c'] as int?) ?? 0;
    final next = count + 1;
    return '$prefix-$year-${next.toString().padLeft(4, '0')}';
  }

  Future<List<Invoice>> getInvoices({String? type, String? dateFrom, String? dateTo}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];
    if (type != null) { conditions.add('i.type = ?'); args.add(type); }
    if (dateFrom != null) { conditions.add('i.date >= ?'); args.add(dateFrom); }
    if (dateTo != null) { conditions.add('i.date <= ?'); args.add(dateTo); }
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final rows = await db.rawQuery('''
      SELECT i.*, a.name as account_name, ca.name as cash_account_name
      FROM invoices i
      LEFT JOIN accounts a ON i.account_id = a.id
      LEFT JOIN accounts ca ON i.cash_account_id = ca.id
      $where
      ORDER BY i.date DESC, i.id DESC
    ''', args.isNotEmpty ? args : null);
    final invoices = rows.map(Invoice.fromMap).toList();
    for (var inv in invoices) {
      final itemRows = await db.rawQuery('''
        SELECT ii.*, p.name as product_name FROM invoice_items ii
        LEFT JOIN products p ON ii.product_id = p.id
        WHERE ii.invoice_id = ?
      ''', [inv.id]);
      inv.items = itemRows.map(InvoiceItem.fromMap).toList();
    }
    return invoices;
  }

  Future<int> insertInvoice(Invoice inv) async {
    if (inv.accountId == null) throw Exception('يجب اختيار حساب العميل/المورد');
    if (inv.items.isEmpty) throw Exception('أضف بنداً واحداً على الأقل');
    if (inv.paid > 0 && inv.cashAccountId == null) throw Exception('اختر حساب الاستلام/الدفع لأن هناك مبلغاً مدفوعاً');

    final db = await database;
    return db.transaction((txn) async {
      final invoiceNumber = await _generateInvoiceNumberTxn(txn, inv.type);
      final invMap = inv.toMap();
      invMap['invoice_number'] = invoiceNumber;
      final id = await txn.insert('invoices', invMap);
      for (var item in inv.items) {
        await txn.insert('invoice_items', {...item.toMap(), 'invoice_id': id});
      }

      final isSale = inv.type == 'بيع';
      final isPurchase = inv.type == 'شراء';
      final isSaleReturn = inv.type == 'مرتجع بيع';
      final isPurchaseReturn = inv.type == 'مرتجع شراء';
      final incomingToStock = isPurchase || isSaleReturn;
      final movementType = incomingToStock ? 'incoming' : 'outgoing';

      double totalCOGS = 0;
      for (var item in inv.items) {
        double unitPriceForMovement = 0;
        if (isPurchase) {
          unitPriceForMovement = item.unitPrice;
        } else if (isSaleReturn) {
          final prod = await txn.query('products', where: 'id = ?', whereArgs: [item.productId]);
          final avg = prod.isNotEmpty ? (prod.first['average_cost'] as num?)?.toDouble() ?? 0 : 0.0;
          unitPriceForMovement = avg;
          totalCOGS += avg * item.quantity;
        }
        // بالنسبة للصادر (بيع / مرتجع شراء) تُترك unitPrice=0 مبدئياً
        // وستُحدَّث تلقائياً أثناء إعادة الحساب بالتكلفة المرجحة الصحيحة في لحظتها

        await txn.insert('warehouse_movements', {
          'product_id': item.productId,
          'warehouse_id': inv.warehouseId,
          'movement_type': movementType,
          'quantity': item.quantity,
          'unit_price': unitPriceForMovement,
          'date': inv.date,
          'reference': invoiceNumber,
          'invoice_id': id,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final productIds = inv.items.map((e) => e.productId).toSet();
      for (var pid in productIds) {
        await _recalculateProductStock(txn, pid);
      }

      if (isSale || isPurchaseReturn) {
        final movRows = await txn.query('warehouse_movements', where: 'invoice_id = ?', whereArgs: [id]);
        totalCOGS = 0;
        for (var m in movRows) {
          totalCOGS += (m['unit_price'] as num).toDouble() * (m['quantity'] as num).toDouble();
        }
      }

      final lines = <JournalLine>[];
      final netRevenue = inv.subtotal - inv.discount;

      if (isSale) {
        if (inv.paid > 0) lines.add(JournalLine(accountId: inv.cashAccountId!, debit: inv.paid));
        if (inv.remaining > 0) lines.add(JournalLine(accountId: inv.accountId!, debit: inv.remaining));
        final revenueAcc = await _getOrCreateSystemAccount(txn, 'إيرادات المبيعات', 'revenue');
        lines.add(JournalLine(accountId: revenueAcc, credit: netRevenue));
        if (inv.tax > 0) {
          final taxAcc = await _getOrCreateSystemAccount(txn, 'ضريبة المبيعات المستحقة', 'liability');
          lines.add(JournalLine(accountId: taxAcc, credit: inv.tax));
        }
        if (totalCOGS > 0) {
          final cogsAcc = await _getOrCreateSystemAccount(txn, 'تكلفة البضاعة المباعة', 'expense');
          final invAcc = await _getOrCreateSystemAccount(txn, 'المخزون', 'asset');
          lines.add(JournalLine(accountId: cogsAcc, debit: totalCOGS));
          lines.add(JournalLine(accountId: invAcc, credit: totalCOGS));
        }
      } else if (isPurchase) {
        final invAcc = await _getOrCreateSystemAccount(txn, 'المخزون', 'asset');
        lines.add(JournalLine(accountId: invAcc, debit: inv.total));
        if (inv.paid > 0) lines.add(JournalLine(accountId: inv.cashAccountId!, credit: inv.paid));
        if (inv.remaining > 0) lines.add(JournalLine(accountId: inv.accountId!, credit: inv.remaining));
      } else if (isSaleReturn) {
        if (inv.paid > 0) lines.add(JournalLine(accountId: inv.cashAccountId!, credit: inv.paid));
        if (inv.remaining > 0) lines.add(JournalLine(accountId: inv.accountId!, credit: inv.remaining));
        final revenueAcc = await _getOrCreateSystemAccount(txn, 'إيرادات المبيعات', 'revenue');
        lines.add(JournalLine(accountId: revenueAcc, debit: netRevenue));
        if (inv.tax > 0) {
          final taxAcc = await _getOrCreateSystemAccount(txn, 'ضريبة المبيعات المستحقة', 'liability');
          lines.add(JournalLine(accountId: taxAcc, debit: inv.tax));
        }
        if (totalCOGS > 0) {
          final cogsAcc = await _getOrCreateSystemAccount(txn, 'تكلفة البضاعة المباعة', 'expense');
          final invAcc = await _getOrCreateSystemAccount(txn, 'المخزون', 'asset');
          lines.add(JournalLine(accountId: invAcc, debit: totalCOGS));
          lines.add(JournalLine(accountId: cogsAcc, credit: totalCOGS));
        }
      } else if (isPurchaseReturn) {
        if (inv.paid > 0) lines.add(JournalLine(accountId: inv.cashAccountId!, debit: inv.paid));
        if (inv.remaining > 0) lines.add(JournalLine(accountId: inv.accountId!, debit: inv.remaining));
        final invAcc = await _getOrCreateSystemAccount(txn, 'المخزون', 'asset');
        lines.add(JournalLine(accountId: invAcc, credit: inv.total));
      }

      if (lines.isNotEmpty) {
        await _insertJournalEntryTxn(txn, JournalEntry(
          date: inv.date,
          description: '${inv.type} - $invoiceNumber',
          reference: invoiceNumber,
          entryType: inv.type,
          relatedInvoiceId: id,
          lines: lines,
        ));
      }

      await _log(txn, 'invoices', id, 'INSERT', new_: inv.toMap());
      return id;
    });
  }

  Future<void> deleteInvoice(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final invRows = await txn.query('invoices', where: 'id = ?', whereArgs: [id]);
      if (invRows.isEmpty) return;

      final relatedEntries = await txn.query('journal_entries', where: 'related_invoice_id = ?', whereArgs: [id]);
      for (var je in relatedEntries) {
        final jeId = je['id'] as int;
        final lines = await _getJournalLines(txn, jeId);
        for (var line in lines) {
          if (line.debit > 0) await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE id = ?', [line.debit, line.accountId]);
          if (line.credit > 0) await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE id = ?', [line.credit, line.accountId]);
        }
        await txn.delete('journal_lines', where: 'journal_entry_id = ?', whereArgs: [jeId]);
        await txn.delete('journal_entries', where: 'id = ?', whereArgs: [jeId]);
      }

      final movRows = await txn.query('warehouse_movements', where: 'invoice_id = ?', whereArgs: [id]);
      final productIds = movRows.map((m) => m['product_id'] as int).toSet();
      await txn.delete('warehouse_movements', where: 'invoice_id = ?', whereArgs: [id]);
      for (var pid in productIds) {
        await _recalculateProductStock(txn, pid);
      }

      await txn.delete('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      await txn.delete('invoices', where: 'id = ?', whereArgs: [id]);
      await _log(txn, 'invoices', id, 'DELETE');
    });
  }

  // تسجيل دفعة لاحقة على فاتورة مفتوحة (تحصيل ذمة عميل أو سداد لمورد)
  Future<void> recordInvoicePayment({
    required int invoiceId,
    required double amount,
    required String date,
    required int cashAccountId,
    String? notes,
  }) async {
    if (amount <= 0) throw Exception('أدخل مبلغاً أكبر من صفر');
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('invoices', where: 'id = ?', whereArgs: [invoiceId]);
      if (rows.isEmpty) throw Exception('الفاتورة غير موجودة');
      final inv = Invoice.fromMap(rows.first);
      if (inv.accountId == null) throw Exception('الفاتورة غير مرتبطة بحساب عميل/مورد');
      if (amount > inv.remaining + 0.01) {
        throw Exception('المبلغ أكبر من المتبقي على الفاتورة (${inv.remaining.toStringAsFixed(2)})');
      }

      final lines = <JournalLine>[];
      if (inv.type == 'بيع') {
        lines.add(JournalLine(accountId: cashAccountId, debit: amount));
        lines.add(JournalLine(accountId: inv.accountId!, credit: amount));
      } else if (inv.type == 'شراء') {
        lines.add(JournalLine(accountId: inv.accountId!, debit: amount));
        lines.add(JournalLine(accountId: cashAccountId, credit: amount));
      } else if (inv.type == 'مرتجع بيع') {
        lines.add(JournalLine(accountId: inv.accountId!, debit: amount));
        lines.add(JournalLine(accountId: cashAccountId, credit: amount));
      } else if (inv.type == 'مرتجع شراء') {
        lines.add(JournalLine(accountId: cashAccountId, debit: amount));
        lines.add(JournalLine(accountId: inv.accountId!, credit: amount));
      }

      await _insertJournalEntryTxn(txn, JournalEntry(
        date: date,
        description: 'دفعة على فاتورة ${inv.invoiceNumber}${notes != null && notes.isNotEmpty ? ' - $notes' : ''}',
        reference: inv.invoiceNumber,
        entryType: 'دفعة',
        relatedInvoiceId: invoiceId,
        lines: lines,
      ));

      final newPaid = inv.paid + amount;
      double newRemaining = inv.total - newPaid;
      if (newRemaining < 0) newRemaining = 0;
      await txn.update('invoices', {'paid': newPaid, 'remaining': newRemaining}, where: 'id = ?', whereArgs: [invoiceId]);
      await _log(txn, 'invoices', invoiceId, 'UPDATE', new_: {'paid': newPaid, 'remaining': newRemaining});
    });
  }

  // ==================== REPORTS (بعملة الأساس، من واقع القيود مباشرة) ====================

  Future<Map<String, double>> getFinancialSummary() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.category as category,
             COALESCE(SUM(jl.debit_base), 0) as total_debit,
             COALESCE(SUM(jl.credit_base), 0) as total_credit
      FROM accounts a
      LEFT JOIN journal_lines jl ON jl.account_id = a.id
      GROUP BY a.category
    ''');
    double totalAssets = 0, totalLiabilities = 0, totalEquity = 0, totalRevenue = 0, totalExpenses = 0;
    for (var r in rows) {
      final debit = (r['total_debit'] as num?)?.toDouble() ?? 0;
      final credit = (r['total_credit'] as num?)?.toDouble() ?? 0;
      final net = debit - credit;
      final category = r['category'] as String?;
      switch (category) {
        case 'asset': totalAssets += net; break;
        case 'liability': totalLiabilities += -net; break;
        case 'equity': totalEquity += -net; break;
        case 'revenue': totalRevenue += -net; break;
        case 'expense': totalExpenses += net; break;
      }
    }
    return {
      'assets': totalAssets,
      'liabilities': totalLiabilities,
      'equity': totalEquity,
      'revenue': totalRevenue,
      'expenses': totalExpenses,
      'net_income': totalRevenue - totalExpenses,
    };
  }

  Future<List<Map<String, dynamic>>> getTrialBalance() async {
    final db = await database;
    return db.rawQuery('''
      SELECT a.id, a.name, a.category,
             COALESCE(SUM(jl.debit_base), 0) as total_debit,
             COALESCE(SUM(jl.credit_base), 0) as total_credit
      FROM accounts a
      LEFT JOIN journal_lines jl ON jl.account_id = a.id
      GROUP BY a.id, a.name, a.category
      HAVING total_debit != 0 OR total_credit != 0
      ORDER BY a.category, a.name
    ''');
  }

  Future<Map<String, dynamic>> getIncomeStatement({String? dateFrom, String? dateTo}) async {
    final db = await database;
    final conditions = <String>["a.category IN ('revenue','expense')"];
    final args = <dynamic>[];
    if (dateFrom != null) { conditions.add('je.date >= ?'); args.add(dateFrom); }
    if (dateTo != null) { conditions.add('je.date <= ?'); args.add(dateTo); }
    final rows = await db.rawQuery('''
      SELECT a.id, a.name, a.category,
             COALESCE(SUM(jl.debit_base), 0) as total_debit,
             COALESCE(SUM(jl.credit_base), 0) as total_credit
      FROM accounts a
      JOIN journal_lines jl ON jl.account_id = a.id
      JOIN journal_entries je ON jl.journal_entry_id = je.id
      WHERE ${conditions.join(' AND ')}
      GROUP BY a.id, a.name, a.category
      HAVING total_debit != 0 OR total_credit != 0
      ORDER BY a.category, a.name
    ''', args);

    final revenues = <Map<String, dynamic>>[];
    final expenses = <Map<String, dynamic>>[];
    double totalRevenue = 0, totalExpense = 0;
    for (var r in rows) {
      final debit = (r['total_debit'] as num).toDouble();
      final credit = (r['total_credit'] as num).toDouble();
      if (r['category'] == 'revenue') {
        final amount = credit - debit;
        revenues.add({'name': r['name'], 'amount': amount});
        totalRevenue += amount;
      } else {
        final amount = debit - credit;
        expenses.add({'name': r['name'], 'amount': amount});
        totalExpense += amount;
      }
    }
    return {
      'revenues': revenues,
      'expenses': expenses,
      'total_revenue': totalRevenue,
      'total_expense': totalExpense,
      'net_income': totalRevenue - totalExpense,
    };
  }

  Future<Map<String, dynamic>> getBalanceSheet({String? asOfDate}) async {
    final db = await database;
    final dateCondition = asOfDate != null ? 'AND je.date <= ?' : '';
    final args = asOfDate != null ? [asOfDate] : [];

    final balRows = await db.rawQuery('''
      SELECT a.id, a.name, a.category,
             COALESCE(SUM(jl.debit_base), 0) as total_debit,
             COALESCE(SUM(jl.credit_base), 0) as total_credit
      FROM accounts a
      LEFT JOIN journal_lines jl ON jl.account_id = a.id
      LEFT JOIN journal_entries je ON jl.journal_entry_id = je.id
      WHERE a.category IN ('asset','liability','equity') $dateCondition
      GROUP BY a.id, a.name, a.category
      HAVING total_debit != 0 OR total_credit != 0
      ORDER BY a.category, a.name
    ''', args);

    final incomeRows = await db.rawQuery('''
      SELECT a.category, COALESCE(SUM(jl.debit_base),0) as total_debit, COALESCE(SUM(jl.credit_base),0) as total_credit
      FROM accounts a
      JOIN journal_lines jl ON jl.account_id = a.id
      JOIN journal_entries je ON jl.journal_entry_id = je.id
      WHERE a.category IN ('revenue','expense') $dateCondition
      GROUP BY a.category
    ''', args);

    double retainedEarnings = 0;
    for (var r in incomeRows) {
      final debit = (r['total_debit'] as num).toDouble();
      final credit = (r['total_credit'] as num).toDouble();
      if (r['category'] == 'revenue') retainedEarnings += (credit - debit);
      if (r['category'] == 'expense') retainedEarnings -= (debit - credit);
    }

    final assets = <Map<String, dynamic>>[];
    final liabilities = <Map<String, dynamic>>[];
    final equity = <Map<String, dynamic>>[];
    double totalAssets = 0, totalLiabilities = 0, totalEquity = 0;
    for (var r in balRows) {
      final debit = (r['total_debit'] as num).toDouble();
      final credit = (r['total_credit'] as num).toDouble();
      final net = debit - credit;
      if (r['category'] == 'asset') {
        assets.add({'name': r['name'], 'amount': net});
        totalAssets += net;
      } else if (r['category'] == 'liability') {
        liabilities.add({'name': r['name'], 'amount': -net});
        totalLiabilities += -net;
      } else {
        equity.add({'name': r['name'], 'amount': -net});
        totalEquity += -net;
      }
    }
    totalEquity += retainedEarnings;

    return {
      'assets': assets,
      'liabilities': liabilities,
      'equity': equity,
      'retained_earnings': retainedEarnings,
      'total_assets': totalAssets,
      'total_liabilities': totalLiabilities,
      'total_equity': totalEquity,
      'balanced': (totalAssets - (totalLiabilities + totalEquity)).abs() < 1,
    };
  }

  Future<List<Map<String, dynamic>>> getAccountStatement(int accountId, {String? dateFrom, String? dateTo}) async {
    final db = await database;
    final conditions = ['jl.account_id = ?'];
    final args = <dynamic>[accountId];
    if (dateFrom != null) { conditions.add('je.date >= ?'); args.add(dateFrom); }
    if (dateTo != null) { conditions.add('je.date <= ?'); args.add(dateTo); }
    return db.rawQuery('''
      SELECT je.id, je.date, je.description, je.reference, jl.debit, jl.credit
      FROM journal_lines jl
      JOIN journal_entries je ON jl.journal_entry_id = je.id
      WHERE ${conditions.join(' AND ')}
      ORDER BY je.date ASC, je.id ASC
    ''', args);
  }

  // ==================== SEARCH ====================
  Future<List<Map<String, dynamic>>> globalSearch(String query) async {
    final db = await database;
    final q = '%$query%';
    final results = <Map<String, dynamic>>[];

    final accounts = await db.rawQuery('SELECT id, name, "account" as source FROM accounts WHERE name LIKE ? LIMIT 5', [q]);
    results.addAll(accounts);

    final entries = await db.rawQuery('SELECT id, description as name, "journal" as source FROM journal_entries WHERE description LIKE ? OR reference LIKE ? LIMIT 5', [q, q]);
    results.addAll(entries);

    final products = await db.rawQuery('SELECT id, name, "product" as source FROM products WHERE name LIKE ? OR code LIKE ? LIMIT 5', [q, q]);
    results.addAll(products);

    return results;
  }

  // ==================== BACKUP ====================
  Future<String> backupDatabase() async {
    final dbPath = await getDatabasesPath();
    final src = File(join(dbPath, 'accounting_v3.db'));
    final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final backupDir = Directory(join(dir.path, 'AccountingBackups'));
    await backupDir.create(recursive: true);
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final dest = File(join(backupDir.path, 'backup_$ts.db'));
    await src.copy(dest.path);
    return dest.path;
  }

  Future<void> shareBackup() async {
    final path = await backupDatabase();
    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'نسخة احتياطية - تطبيق المحاسبة'));
  }

  Future<void> restoreDatabase(String filePath) async {
    final dbPath = await getDatabasesPath();
    final dest = File(join(dbPath, 'accounting_v3.db'));
    if (_db != null) { await _db!.close(); _db = null; }
    await File(filePath).copy(dest.path);
  }

  Future<List<String>> getBackupFiles() async {
    try {
      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final backupDir = Directory(join(dir.path, 'AccountingBackups'));
      if (!await backupDir.exists()) return [];
      final files = await backupDir.list().toList();
      final paths = files.whereType<File>().map((f) => f.path).toList();
      paths.sort((a, b) => b.compareTo(a));
      return paths;
    } catch (e) {
      return [];
    }
  }
}
