import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

enum LedgerEntryType { expense, income }

class LedgerCategoryDto {
  final int id;
  final String name;
  final LedgerEntryType type;
  final String iconCode;
  final String? colorKey;

  const LedgerCategoryDto({
    required this.id,
    required this.name,
    required this.type,
    required this.iconCode,
    this.colorKey,
  });

  factory LedgerCategoryDto.fromMap(Map<String, Object?> map) {
    return LedgerCategoryDto(
      id: map['id'] as int,
      name: map['name'] as String,
      type: _typeFromName(map['type'] as String?),
      iconCode: map['icon_code'] as String,
      colorKey: map['color_key'] as String?,
    );
  }
}

class LedgerAccountDto {
  final int id;
  final String name;
  final String iconCode;
  final String? colorKey;

  const LedgerAccountDto({
    required this.id,
    required this.name,
    required this.iconCode,
    this.colorKey,
  });

  factory LedgerAccountDto.fromMap(Map<String, Object?> map) {
    return LedgerAccountDto(
      id: map['id'] as int,
      name: map['name'] as String,
      iconCode: map['icon_code'] as String,
      colorKey: map['color_key'] as String?,
    );
  }
}

class LedgerTransactionDto {
  final int id;
  final String transactionNo;
  final LedgerEntryType type;
  final double amount;
  final int categoryId;
  final String categoryName;
  final int accountId;
  final String accountName;
  final String note;
  final DateTime transactionTime;
  final String source;
  final String iconCode;
  final int receiptCount;
  final List<String> receiptImagePaths;

  const LedgerTransactionDto({
    required this.id,
    required this.transactionNo,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.accountId,
    required this.accountName,
    required this.note,
    required this.transactionTime,
    required this.source,
    required this.iconCode,
    this.receiptCount = 0,
    this.receiptImagePaths = const [],
  });

  double get signedAmount =>
      type == LedgerEntryType.income ? amount : -amount.abs();

  factory LedgerTransactionDto.fromMap(Map<String, Object?> map) {
    final rawTime = map['transaction_time'] as String;
    return LedgerTransactionDto(
      id: map['id'] as int,
      transactionNo: map['transaction_no'] as String,
      type: _typeFromName(map['type'] as String?),
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String,
      accountId: map['account_id'] as int,
      accountName: map['account_name'] as String,
      note: (map['note'] as String?) ?? '',
      transactionTime: _toMinutePrecision(
        DateTime.tryParse(rawTime) ?? DateTime.now(),
      ),
      source: (map['source'] as String?) ?? 'manual',
      iconCode: (map['icon_code'] as String?) ?? 'more_horiz',
      receiptCount: (map['receipt_count'] as int?) ?? 0,
      receiptImagePaths: ((map['receipt_paths'] as String?) ?? '')
          .split('|||')
          .where((path) => path.trim().isNotEmpty)
          .toList(),
    );
  }
}

class CreateLedgerTransactionInput {
  final LedgerEntryType type;
  final double amount;
  final int categoryId;
  final int accountId;
  final String note;
  final DateTime transactionTime;
  final String source;
  final List<String> receiptImagePaths;

  const CreateLedgerTransactionInput({
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    this.note = '',
    required this.transactionTime,
    this.source = 'manual',
    this.receiptImagePaths = const [],
  });
}

class UpdateLedgerTransactionInput {
  final LedgerEntryType type;
  final double amount;
  final int categoryId;
  final int accountId;
  final String note;
  final DateTime transactionTime;
  final List<String>? receiptImagePaths;

  const UpdateLedgerTransactionInput({
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    this.note = '',
    required this.transactionTime,
    this.receiptImagePaths,
  });
}

class MonthlyBudgetDto {
  final DateTime month;
  final double? budgetAmount;
  final double spentAmount;

  const MonthlyBudgetDto({
    required this.month,
    required this.budgetAmount,
    required this.spentAmount,
  });

  bool get isSet => budgetAmount != null;
  double? get remaining =>
      budgetAmount == null ? null : budgetAmount! - spentAmount;
  bool get isOverBudget =>
      budgetAmount != null && budgetAmount! > 0 && spentAmount > budgetAmount!;
  double get overAmount => isOverBudget ? spentAmount - budgetAmount! : 0;
  double get progress {
    final budget = budgetAmount;
    if (budget == null || budget <= 0) return 0;
    return (spentAmount / budget).clamp(0.0, 1.0);
  }
}

class BudgetCheckResult {
  final bool isOverBudget;
  final double overAmount;
  final MonthlyBudgetDto budget;

  const BudgetCheckResult({
    required this.isOverBudget,
    required this.overAmount,
    required this.budget,
  });
}

class BackupPackageDto {
  final String fileName;
  final Uint8List bytes;
  final int fileSize;
  final DateTime createdAt;
  final int transactionCount;
  final int diaryCount;

  const BackupPackageDto({
    required this.fileName,
    required this.bytes,
    required this.fileSize,
    required this.createdAt,
    required this.transactionCount,
    required this.diaryCount,
  });
}

class BackupImportResult {
  final int transactionCount;
  final int diaryCount;
  final int budgetCount;

  const BackupImportResult({
    required this.transactionCount,
    required this.diaryCount,
    required this.budgetCount,
  });
}

class DiaryEntryDto {
  final int id;
  final DateTime entryDate;
  final String content;
  final String moodKey;
  final String moodLabel;
  final String moodIcon;
  final String weatherKey;
  final String weatherLabel;
  final String weatherIcon;
  final String lunarDate;
  final String? locationName;
  final List<String> images;

  const DiaryEntryDto({
    required this.id,
    required this.entryDate,
    required this.content,
    required this.moodKey,
    required this.moodLabel,
    required this.moodIcon,
    required this.weatherKey,
    required this.weatherLabel,
    required this.weatherIcon,
    required this.lunarDate,
    this.locationName,
    required this.images,
  });

  bool get hasBody => content.trim().isNotEmpty || images.isNotEmpty;
}

class SaveDiaryEntryInput {
  final int? id;
  final DateTime entryDate;
  final String content;
  final String moodKey;
  final String moodLabel;
  final String moodIcon;
  final String weatherKey;
  final String weatherLabel;
  final String weatherIcon;
  final String lunarDate;
  final String? locationName;
  final List<String> images;

  const SaveDiaryEntryInput({
    this.id,
    required this.entryDate,
    required this.content,
    required this.moodKey,
    required this.moodLabel,
    required this.moodIcon,
    required this.weatherKey,
    required this.weatherLabel,
    required this.weatherIcon,
    required this.lunarDate,
    this.locationName,
    required this.images,
  });
}

class LocalDataApi {
  LocalDataApi._();

  static final LocalDataApi instance = LocalDataApi._();
  final ValueNotifier<int> transactionsVersion = ValueNotifier<int>(0);
  final ValueNotifier<int> budgetVersion = ValueNotifier<int>(0);
  final ValueNotifier<int> diaryVersion = ValueNotifier<int>(0);

  Future<List<LedgerCategoryDto>> listLedgerCategories({
    required LedgerEntryType type,
  }) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'ledger_categories',
      where: 'type = ? AND is_enabled = 1 AND deleted_at IS NULL',
      whereArgs: [type.name],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(LedgerCategoryDto.fromMap).toList();
  }

  Future<List<LedgerAccountDto>> listLedgerAccounts() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'ledger_accounts',
      where: 'is_enabled = 1 AND deleted_at IS NULL',
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows.map(LedgerAccountDto.fromMap).toList();
  }

  Future<int> createLedgerTransaction(
    CreateLedgerTransactionInput input,
  ) async {
    final id = await _createSqliteTransaction(input);
    transactionsVersion.value++;
    if (input.type == LedgerEntryType.expense) {
      budgetVersion.value++;
    }
    return id;
  }

  Future<void> updateLedgerTransaction(
    int id,
    UpdateLedgerTransactionInput input,
  ) async {
    final shouldRefreshBudget = await _updateSqliteTransaction(id, input);
    transactionsVersion.value++;
    if (shouldRefreshBudget) {
      budgetVersion.value++;
    }
  }

  Future<void> deleteLedgerTransaction(int id) async {
    final shouldRefreshBudget = await _deleteSqliteTransaction(id);
    transactionsVersion.value++;
    if (shouldRefreshBudget) {
      budgetVersion.value++;
    }
  }

  Future<List<LedgerTransactionDto>> listTransactions() async {
    final db = await DatabaseHelper().database;
    final rows = await db.rawQuery('''
        SELECT
        t.id,
        t.transaction_no,
        t.type,
        t.amount,
        t.category_id,
        t.category_name,
        t.account_id,
        t.account_name,
        t.note,
        t.transaction_time,
          t.source,
          c.icon_code,
          COUNT(a.id) AS receipt_count,
          GROUP_CONCAT(a.file_path, '|||') AS receipt_paths
        FROM ledger_transactions t
      LEFT JOIN ledger_categories c ON c.id = t.category_id
      LEFT JOIN transaction_attachments a
        ON a.transaction_id = t.id AND a.deleted_at IS NULL
      WHERE t.deleted_at IS NULL
      GROUP BY t.id
      ORDER BY t.transaction_time DESC
    ''');
    return rows.map(LedgerTransactionDto.fromMap).toList();
  }

  /// /api/budget/get
  Future<MonthlyBudgetDto> getBudget({DateTime? month}) async {
    final targetMonth = _monthStart(month ?? DateTime.now());
    final db = await DatabaseHelper().database;
    final monthKey = _monthKey(targetMonth);
    final budgetRows = await db.query(
      'monthly_budgets',
      where: 'budget_month = ? AND deleted_at IS NULL',
      whereArgs: [monthKey],
      limit: 1,
    );
    final expenseRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM ledger_transactions
      WHERE deleted_at IS NULL
        AND type = ?
        AND transaction_time >= ?
        AND transaction_time < ?
      ''',
      [
        LedgerEntryType.expense.name,
        targetMonth.toIso8601String(),
        DateTime(targetMonth.year, targetMonth.month + 1).toIso8601String(),
      ],
    );
    return MonthlyBudgetDto(
      month: targetMonth,
      budgetAmount: budgetRows.isEmpty
          ? null
          : (budgetRows.first['amount'] as num).toDouble(),
      spentAmount: ((expenseRows.first['total'] as num?) ?? 0).toDouble(),
    );
  }

  /// /api/budget/set
  Future<MonthlyBudgetDto> setBudget({
    required DateTime month,
    required double amount,
  }) async {
    final targetMonth = _monthStart(month);
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();
    await db.insert('monthly_budgets', {
      'budget_month': _monthKey(targetMonth),
      'amount': amount.abs(),
      'currency': 'CNY',
      'sync_status': 'local',
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final budget = await getBudget(month: targetMonth);
    budgetVersion.value++;
    return budget;
  }

  /// /api/budget/check
  Future<BudgetCheckResult> checkBudget({DateTime? month}) async {
    final budget = await getBudget(month: month);
    return BudgetCheckResult(
      isOverBudget: budget.isOverBudget,
      overAmount: budget.overAmount,
      budget: budget,
    );
  }

  /// /api/backup/export
  Future<BackupPackageDto> exportBackupPackage() async {
    final createdAt = DateTime.now();
    final tables = await _exportSqliteTables();
    final transactionCount =
        (tables['ledger_transactions'] as List? ?? const []).length;
    final diaryCount = (tables['diary_entries'] as List? ?? const []).length;
    final assetFiles = await _collectBackupAssetFiles(tables);
    final payload = {
      'schema': 'tallyjie.backup.v1',
      'app': 'TallyJie',
      'created_at': createdAt.toIso8601String(),
      'files': assetFiles
          .map(
            (file) => {
              'original_path': file.originalPath,
              'archive_path': file.archivePath,
              'file_name': file.fileName,
            },
          )
          .toList(),
      'tables': tables,
    };
    final jsonBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    final archive = Archive();
    for (final file in assetFiles) {
      archive.addFile(
        ArchiveFile(file.archivePath, file.bytes.length, file.bytes),
      );
    }
    archive.addFile(
      ArchiveFile('tallyjie_backup.json', jsonBytes.length, jsonBytes),
    );
    final zipBytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));
    final fileName =
        'TallyJie_backup_${createdAt.year}${createdAt.month.toString().padLeft(2, '0')}'
        '${createdAt.day.toString().padLeft(2, '0')}_'
        '${createdAt.hour.toString().padLeft(2, '0')}'
        '${createdAt.minute.toString().padLeft(2, '0')}.zip';

    await _insertBackupRecord(
      type: 'export',
      filePath: fileName,
      fileName: fileName,
      fileSize: zipBytes.length,
      status: 'success',
    );

    return BackupPackageDto(
      fileName: fileName,
      bytes: zipBytes,
      fileSize: zipBytes.length,
      createdAt: createdAt,
      transactionCount: transactionCount,
      diaryCount: diaryCount,
    );
  }

  /// /api/backup/import
  Future<BackupImportResult> importBackupPackage(
    Uint8List bytes, {
    String? fileName,
  }) async {
    final decoded = _decodeBackupPayload(bytes);
    final payload = decoded.payload;
    if (payload['schema'] != 'tallyjie.backup.v1') {
      throw FormatException('不是有效的 TallyJie 备份文件');
    }
    await _restoreBackupFiles(payload, decoded.archiveFiles);
    final tables = (payload['tables'] as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );

    final result = await _importSqliteTables(tables);

    transactionsVersion.value++;
    budgetVersion.value++;
    diaryVersion.value++;

    await _insertBackupRecord(
      type: 'import',
      filePath: fileName ?? 'local',
      fileName: fileName ?? 'TallyJie_backup.zip',
      fileSize: bytes.length,
      status: 'success',
    );
    return result;
  }

  Future<List<DateTime>> listDiaryEntryDates() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'diary_entries',
      distinct: true,
      columns: ['entry_date'],
      where: 'deleted_at IS NULL',
      orderBy: 'entry_date ASC',
    );
    return rows
        .map((row) => DateTime.tryParse(row['entry_date'] as String))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toList();
  }

  Future<DiaryEntryDto?> getDiaryEntry(DateTime date) async {
    final entries = await listDiaryEntries(date);
    return entries.isEmpty ? null : entries.first;
  }

  Future<List<DiaryEntryDto>> listDiaryEntries(DateTime date) async {
    final entryDate = _dateKey(date);
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'diary_entries',
      where: 'entry_date = ? AND deleted_at IS NULL',
      whereArgs: [entryDate],
      orderBy: 'created_at DESC, id DESC',
    );
    final entries = <DiaryEntryDto>[];
    for (final row in rows) {
      entries.add(await _diaryDtoFromRow(db, row));
    }
    return entries;
  }

  Future<DiaryEntryDto> _diaryDtoFromRow(
    Database db,
    Map<String, Object?> row,
  ) async {
    final attachments = await db.query(
      'diary_attachments',
      where: 'diary_id = ? AND deleted_at IS NULL',
      whereArgs: [row['id']],
      orderBy: 'sort_order ASC, id ASC',
    );
    return DiaryEntryDto(
      id: row['id'] as int,
      entryDate: DateTime.parse(row['entry_date'] as String),
      content: (row['content'] as String?) ?? '',
      moodKey: (row['mood_key'] as String?) ?? 'happy',
      moodLabel: (row['mood_label'] as String?) ?? '开心',
      moodIcon: (row['mood_icon'] as String?) ?? '😊',
      weatherKey: (row['weather_key'] as String?) ?? 'sunny',
      weatherLabel: (row['weather_label'] as String?) ?? '晴',
      weatherIcon: (row['weather_icon'] as String?) ?? '☀️',
      lunarDate: (row['lunar_date'] as String?) ?? '',
      locationName: row['location_name'] as String?,
      images: attachments
          .map((attachment) => attachment['file_path'] as String)
          .toList(),
    );
  }

  Future<DiaryEntryDto> saveDiaryEntry(SaveDiaryEntryInput input) async {
    final entry = await _saveSqliteDiaryEntry(input);
    diaryVersion.value++;
    return entry;
  }

  Future<void> deleteDiaryEntry(DateTime date) async {
    final entry = await getDiaryEntry(date);
    if (entry == null) return;
    return deleteDiaryEntryById(entry.id);
  }

  Future<void> deleteDiaryEntryById(int id) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'diary_entries',
      {'deleted_at': now, 'sync_status': 'pending_delete', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.update(
      'diary_attachments',
      {'deleted_at': now, 'sync_status': 'pending_delete'},
      where: 'diary_id = ?',
      whereArgs: [id],
    );
    diaryVersion.value++;
  }

  Future<Map<String, List<Map<String, Object?>>>> _exportSqliteTables() async {
    final db = await DatabaseHelper().database;
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in _backupTableNames) {
      result[table] = await db.query(table);
    }
    return result;
  }

  Future<BackupImportResult> _importSqliteTables(
    Map<String, Object?> tables,
  ) async {
    final db = await DatabaseHelper().database;
    final normalized = <String, List<Map<String, Object?>>>{};
    for (final table in _backupTableNames) {
      final rows = tables[table];
      normalized[table] = rows is List
          ? rows
                .whereType<Map>()
                .map(
                  (row) => row.map(
                    (key, value) => MapEntry(key.toString(), value as Object?),
                  ),
                )
                .toList()
          : <Map<String, Object?>>[];
    }

    await db.transaction((txn) async {
      for (final table in _backupDeleteOrder) {
        await txn.delete(table);
      }
      for (final table in _backupInsertOrder) {
        for (final row in normalized[table] ?? const <Map<String, Object?>>[]) {
          await txn.insert(
            table,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    return BackupImportResult(
      transactionCount: normalized['ledger_transactions']?.length ?? 0,
      diaryCount: normalized['diary_entries']?.length ?? 0,
      budgetCount: normalized['monthly_budgets']?.length ?? 0,
    );
  }

  Future<void> _insertBackupRecord({
    required String type,
    required String filePath,
    required String fileName,
    required int fileSize,
    required String status,
  }) async {
    final db = await DatabaseHelper().database;
    await db.insert('backup_records', {
      'type': type,
      'file_path': filePath,
      'file_name': fileName,
      'file_size': fileSize,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> _createSqliteTransaction(
    CreateLedgerTransactionInput input,
  ) async {
    final db = await DatabaseHelper().database;
    final categoryRows = await db.query(
      'ledger_categories',
      where: 'id = ?',
      whereArgs: [input.categoryId],
      limit: 1,
    );
    final accountRows = await db.query(
      'ledger_accounts',
      where: 'id = ?',
      whereArgs: [input.accountId],
      limit: 1,
    );
    if (categoryRows.isEmpty || accountRows.isEmpty) {
      throw StateError('分类或账户不存在');
    }

    final now = DateTime.now().toIso8601String();
    final category = categoryRows.first;
    final account = accountRows.first;
    final transactionId = await db.insert('ledger_transactions', {
      'transaction_no': _buildTransactionNo(now),
      'type': input.type.name,
      'amount': input.amount.abs(),
      'category_id': input.categoryId,
      'category_name': category['name'],
      'account_id': input.accountId,
      'account_name': account['name'],
      'note': input.note.trim(),
      'transaction_time': _toMinutePrecision(
        input.transactionTime,
      ).toIso8601String(),
      'source': input.source,
      'sync_status': 'local',
      'created_at': now,
      'updated_at': now,
    });
    final receiptImagePaths = await _persistLocalAssetPaths(
      input.receiptImagePaths,
      bucket: 'receipt',
    );
    for (var i = 0; i < receiptImagePaths.length; i++) {
      final path = receiptImagePaths[i];
      await db.insert('transaction_attachments', {
        'transaction_id': transactionId,
        'file_path': path,
        'file_name': path.split(RegExp(r'[/\\]')).last,
        'file_type': 'image',
        'file_size': 0,
        'sync_status': 'local',
        'created_at': now,
      });
    }
    return transactionId;
  }

  Future<bool> _updateSqliteTransaction(
    int id,
    UpdateLedgerTransactionInput input,
  ) async {
    final db = await DatabaseHelper().database;
    final existingRows = await db.query(
      'ledger_transactions',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (existingRows.isEmpty) return false;

    final categoryRows = await db.query(
      'ledger_categories',
      where: 'id = ?',
      whereArgs: [input.categoryId],
      limit: 1,
    );
    final accountRows = await db.query(
      'ledger_accounts',
      where: 'id = ?',
      whereArgs: [input.accountId],
      limit: 1,
    );
    if (categoryRows.isEmpty || accountRows.isEmpty) {
      throw StateError('分类或账户不存在');
    }

    final oldType = _typeFromName(existingRows.first['type'] as String?);
    final now = DateTime.now().toIso8601String();
    await db.update(
      'ledger_transactions',
      {
        'type': input.type.name,
        'amount': input.amount.abs(),
        'category_id': input.categoryId,
        'category_name': categoryRows.first['name'],
        'account_id': input.accountId,
        'account_name': accountRows.first['name'],
        'note': input.note.trim(),
        'transaction_time': _toMinutePrecision(
          input.transactionTime,
        ).toIso8601String(),
        'sync_status': 'pending_update',
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (input.receiptImagePaths != null) {
      final receiptImagePaths = await _persistLocalAssetPaths(
        input.receiptImagePaths!,
        bucket: 'receipt',
      );
      await db.update(
        'transaction_attachments',
        {'deleted_at': now, 'sync_status': 'pending_delete'},
        where: 'transaction_id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      for (final path in receiptImagePaths) {
        await db.insert('transaction_attachments', {
          'transaction_id': id,
          'file_path': path,
          'file_name': path.split(RegExp(r'[/\\]')).last,
          'file_type': 'image',
          'file_size': 0,
          'sync_status': 'pending_create',
          'created_at': now,
        });
      }
    }
    return oldType == LedgerEntryType.expense ||
        input.type == LedgerEntryType.expense;
  }

  Future<bool> _deleteSqliteTransaction(int id) async {
    final db = await DatabaseHelper().database;
    final existingRows = await db.query(
      'ledger_transactions',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (existingRows.isEmpty) return false;

    final oldType = _typeFromName(existingRows.first['type'] as String?);
    final now = DateTime.now().toIso8601String();
    await db.update(
      'ledger_transactions',
      {'deleted_at': now, 'sync_status': 'pending_delete', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    await db.update(
      'transaction_attachments',
      {'deleted_at': now, 'sync_status': 'pending_delete'},
      where: 'transaction_id = ?',
      whereArgs: [id],
    );
    return oldType == LedgerEntryType.expense;
  }

  String _buildTransactionNo(String now) {
    return 'tx_${now.replaceAll(RegExp(r'[^0-9]'), '')}_'
        '${DateTime.now().microsecondsSinceEpoch}';
  }

  Future<DiaryEntryDto> _saveSqliteDiaryEntry(SaveDiaryEntryInput input) async {
    final db = await DatabaseHelper().database;
    final now = DateTime.now().toIso8601String();
    final dateKey = _dateKey(input.entryDate);
    late final int entryId;
    final values = {
      'entry_date': dateKey,
      'content': input.content.trim(),
      'markdown_content': input.content.trim(),
      'mood_key': input.moodKey,
      'mood_label': input.moodLabel,
      'mood_icon': input.moodIcon,
      'weather_key': input.weatherKey,
      'weather_label': input.weatherLabel,
      'weather_icon': input.weatherIcon,
      'lunar_date': input.lunarDate,
      'location_name': input.locationName?.trim(),
      'sync_status': 'local',
      'deleted_at': null,
      'updated_at': now,
    };
    if (input.id == null) {
      entryId = await db.insert('diary_entries', {
        ...values,
        'created_at': now,
      });
    } else {
      entryId = input.id!;
      await db.update(
        'diary_entries',
        values,
        where: 'id = ?',
        whereArgs: [entryId],
      );
      await db.delete(
        'diary_attachments',
        where: 'diary_id = ?',
        whereArgs: [entryId],
      );
    }

    final images = await _persistLocalAssetPaths(input.images, bucket: 'diary');
    for (var i = 0; i < images.length; i++) {
      final path = images[i];
      await db.insert('diary_attachments', {
        'diary_id': entryId,
        'type': 'image',
        'file_path': path,
        'file_name': path.split(RegExp(r'[/\\]')).last,
        'file_size': 0,
        'sort_order': i,
        'sync_status': 'local',
        'created_at': now,
      });
    }
    final rows = await db.query(
      'diary_entries',
      where: 'id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    return _diaryDtoFromRow(db, rows.first);
  }
}

DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _monthKey(DateTime date) {
  final month = _monthStart(date);
  return '${month.year}-${month.month.toString().padLeft(2, '0')}';
}

Future<List<String>> _persistLocalAssetPaths(
  List<String> paths, {
  required String bucket,
}) async {
  if (paths.isEmpty) return List.of(paths);

  final supportDir = await getApplicationSupportDirectory();
  final supportPath = supportDir.path;
  final savedPaths = <String>[];
  for (var i = 0; i < paths.length; i++) {
    final path = paths[i];
    if (path.startsWith('http') ||
        path.startsWith(supportPath)) {
      savedPaths.add(path);
      continue;
    }

    try {
      final bytes = await XFile(path).readAsBytes();
      final originalName = _assetFileName(path, fallback: '$bucket-$i.jpg');
      final fileName =
          'tallyjie_${bucket}_${DateTime.now().microsecondsSinceEpoch}_'
          '${i}_$originalName';
      final targetPath = '$supportPath/$fileName';
      await XFile.fromData(bytes, name: originalName).saveTo(targetPath);
      savedPaths.add(targetPath);
    } catch (_) {
      savedPaths.add(path);
    }
  }
  return savedPaths;
}

String _assetFileName(String path, {required String fallback}) {
  final name = path.split(RegExp(r'[/\\]')).last.trim();
  if (name.isEmpty || name.contains(':')) return fallback;
  return name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}

const _backupTableNames = [
  'theme_settings',
  'diary_entries',
  'diary_attachments',
  'daily_tasks',
  'ledger_categories',
  'ledger_accounts',
  'ledger_transactions',
  'transaction_attachments',
  'auto_detected_bills',
  'monthly_budgets',
  'app_settings',
];

const _backupDeleteOrder = [
  'auto_detected_bills',
  'transaction_attachments',
  'ledger_transactions',
  'diary_attachments',
  'diary_entries',
  'daily_tasks',
  'monthly_budgets',
  'ledger_categories',
  'ledger_accounts',
  'theme_settings',
  'app_settings',
];

const _backupInsertOrder = [
  'theme_settings',
  'app_settings',
  'ledger_categories',
  'ledger_accounts',
  'daily_tasks',
  'diary_entries',
  'diary_attachments',
  'ledger_transactions',
  'transaction_attachments',
  'auto_detected_bills',
  'monthly_budgets',
];

class _BackupAssetFile {
  final String originalPath;
  final String archivePath;
  final String fileName;
  final Uint8List bytes;

  const _BackupAssetFile({
    required this.originalPath,
    required this.archivePath,
    required this.fileName,
    required this.bytes,
  });
}

class _DecodedBackupPayload {
  final Map<String, Object?> payload;
  final Map<String, Uint8List> archiveFiles;

  const _DecodedBackupPayload({
    required this.payload,
    required this.archiveFiles,
  });
}

Future<List<_BackupAssetFile>> _collectBackupAssetFiles(
  Map<String, List<Map<String, Object?>>> tables,
) async {
  final paths = <String>{};
  for (final table in ['diary_attachments', 'transaction_attachments']) {
    for (final row in tables[table] ?? const <Map<String, Object?>>[]) {
      final path = (row['file_path'] as String?)?.trim();
      if (path != null && path.isNotEmpty) paths.add(path);
    }
  }

  final result = <_BackupAssetFile>[];
  var index = 0;
  for (final path in paths) {
    try {
      final bytes = await XFile(path).readAsBytes();
      if (bytes.isEmpty) continue;
      final fileName = path.split(RegExp(r'[/\\]')).last;
      final safeName = fileName.isEmpty ? 'asset_$index' : fileName;
      result.add(
        _BackupAssetFile(
          originalPath: path,
          archivePath: 'files/${index.toString().padLeft(4, '0')}_$safeName',
          fileName: safeName,
          bytes: bytes,
        ),
      );
      index++;
    } catch (_) {
      // Ignore missing local files; the original path remains in the JSON.
    }
  }
  return result;
}

Future<void> _restoreBackupFiles(
  Map<String, Object?> payload,
  Map<String, Uint8List> archiveFiles,
) async {
  final files = payload['files'];
  if (files is! List || files.isEmpty || archiveFiles.isEmpty) return;

  final supportDir = await getApplicationSupportDirectory();
  final importedAt = DateTime.now().millisecondsSinceEpoch;
  final pathMap = <String, String>{};

  for (final item in files.whereType<Map>()) {
    final originalPath = item['original_path'] as String?;
    final archivePath = item['archive_path'] as String?;
    final fileName = item['file_name'] as String? ?? 'asset';
    if (originalPath == null || archivePath == null) continue;
    final bytes = archiveFiles[archivePath];
    if (bytes == null) continue;
    final targetPath =
        '${supportDir.path}/tallyjie_import_${importedAt}_${pathMap.length}_$fileName';
    await XFile.fromData(bytes, name: fileName).saveTo(targetPath);
    pathMap[originalPath] = targetPath;
  }

  if (pathMap.isEmpty) return;
  final tables = payload['tables'];
  if (tables is! Map) return;
  for (final table in ['diary_attachments', 'transaction_attachments']) {
    final rows = tables[table];
    if (rows is! List) continue;
    for (final row in rows.whereType<Map>()) {
      final originalPath = row['file_path'] as String?;
      final restoredPath = pathMap[originalPath];
      if (restoredPath != null) row['file_path'] = restoredPath;
    }
  }
}

_DecodedBackupPayload _decodeBackupPayload(Uint8List bytes) {
  String jsonText;
  final archiveFiles = <String, Uint8List>{};
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final file = archive.files.firstWhere(
      (file) =>
          file.name.endsWith('tallyjie_backup.json') ||
          file.name.endsWith('.json'),
    );
    for (final archiveFile in archive.files) {
      if (archiveFile.isFile) {
        archiveFiles[archiveFile.name] = archiveFile.content;
      }
    }
    jsonText = utf8.decode(file.content);
  } catch (_) {
    jsonText = utf8.decode(bytes);
  }
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    throw const FormatException('备份文件内容不完整');
  }
  return _DecodedBackupPayload(
    payload: decoded.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    ),
    archiveFiles: archiveFiles,
  );
}

class LedgerIconCatalog {
  LedgerIconCatalog._();

  static IconData icon(String code) {
    return _icons[code] ?? Icons.more_horiz;
  }

  static const _icons = <String, IconData>{
    'restaurant_outlined': Icons.restaurant_outlined,
    'directions_car_outlined': Icons.directions_car_outlined,
    'shopping_bag_outlined': Icons.shopping_bag_outlined,
    'home_outlined': Icons.home_outlined,
    'lightbulb_outline': Icons.lightbulb_outline,
    'phone_iphone_outlined': Icons.phone_iphone_outlined,
    'sports_esports_outlined': Icons.sports_esports_outlined,
    'menu_book_outlined': Icons.menu_book_outlined,
    'medical_services_outlined': Icons.medical_services_outlined,
    'flight_takeoff_outlined': Icons.flight_takeoff_outlined,
    'cruelty_free_outlined': Icons.cruelty_free_outlined,
    'card_giftcard_outlined': Icons.card_giftcard_outlined,
    'spa_outlined': Icons.spa_outlined,
    'checkroom_outlined': Icons.checkroom_outlined,
    'brush_outlined': Icons.brush_outlined,
    'directions_run_outlined': Icons.directions_run_outlined,
    'devices_outlined': Icons.devices_outlined,
    'payments_outlined': Icons.payments_outlined,
    'redeem_outlined': Icons.redeem_outlined,
    'trending_up_outlined': Icons.trending_up_outlined,
    'work_outline': Icons.work_outline,
    'credit_card_outlined': Icons.credit_card_outlined,
    'keyboard_return_outlined': Icons.keyboard_return_outlined,
    'account_balance_outlined': Icons.account_balance_outlined,
    'insert_chart_outlined': Icons.insert_chart_outlined,
    'chat_bubble_outline': Icons.chat_bubble_outline,
    'account_balance_wallet_outlined': Icons.account_balance_wallet_outlined,
    'money_outlined': Icons.money_outlined,
    'more_horiz': Icons.more_horiz,
  };
}

LedgerEntryType _typeFromName(String? value) {
  return value == LedgerEntryType.income.name
      ? LedgerEntryType.income
      : LedgerEntryType.expense;
}

DateTime _toMinutePrecision(DateTime value) {
  return DateTime(value.year, value.month, value.day, value.hour, value.minute);
}
