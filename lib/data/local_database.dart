import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/models.dart';

/// قاعدة SQLite محلية. كل عمليات الاستيراد تتم داخل معاملة واحدة، بحيث لا
/// تُفقد المصادر الأخرى عند فشل تحديث مصدر واحد.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'atlas_souq.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE projects(
            id TEXT PRIMARY KEY, name TEXT NOT NULL, created_at INTEGER NOT NULL)
        ''');
        await db.execute('''
          CREATE TABLE candidates(
            id TEXT PRIMARY KEY, project_id TEXT NOT NULL, name TEXT,
            note TEXT, lat REAL NOT NULL, lon REAL NOT NULL,
            radius REAL NOT NULL, created_at INTEGER NOT NULL)
        ''');
        await db.execute('''
          CREATE TABLE sources(
            id TEXT PRIMARY KEY, name TEXT NOT NULL, year INTEGER,
            publisher TEXT, url TEXT, checked_at INTEGER,
            kind TEXT, coverage TEXT)
        ''');
        await db.execute('''
          CREATE TABLE imported_branches(
            id TEXT PRIMARY KEY, source TEXT NOT NULL, brand TEXT,
            name TEXT, lat REAL, lon REAL, region TEXT, city TEXT,
            district TEXT, address TEXT, verification TEXT, updated_at INTEGER)
        ''');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
      },
    );
    return _db!;
  }

  Future<String> createProject(String name) async {
    final db = await database;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await db.insert('projects', {'id': id, 'name': name, 'created_at': DateTime.now().millisecondsSinceEpoch});
    return id;
  }

  Future<List<Project>> loadProjects() async {
    final db = await database;
    final projectRows = await db.query('projects', orderBy: 'created_at DESC');
    final candidateRows = await db.query('candidates', orderBy: 'created_at DESC');
    return projectRows.map((r) {
      final candidates = candidateRows
          .where((c) => c['project_id'] == r['id'])
          .map((c) => Candidate(
                id: c['id'] as String,
                projectId: c['project_id'] as String,
                name: (c['name'] as String?) ?? '',
                note: (c['note'] as String?) ?? '',
                lat: (c['lat'] as num?)?.toDouble() ?? 0,
                lon: (c['lon'] as num?)?.toDouble() ?? 0,
                radiusKm: (c['radius'] as num?)?.toDouble() ?? 5,
                createdAt: DateTime.fromMillisecondsSinceEpoch((c['created_at'] as num?)?.toInt() ?? 0),
              ))
          .toList();
      return Project(
        id: r['id'] as String,
        name: r['name'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch((r['created_at'] as num?)?.toInt() ?? 0),
        candidates: candidates,
      );
    }).toList();
  }

  Future<void> saveCandidate(Candidate c) async {
    final db = await database;
    await db.insert(
      'candidates',
      {
        'id': c.id,
        'project_id': c.projectId,
        'name': c.name,
        'note': c.note,
        'lat': c.lat,
        'lon': c.lon,
        'radius': c.radiusKm,
        'created_at': c.createdAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCandidate(String id) async {
    final db = await database;
    await db.delete('candidates', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> renameCandidate(String id, String name, String note, double radius) async {
    final db = await database;
    await db.update(
      'candidates',
      {'name': name, 'note': note, 'radius': radius},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> importedBranches({String? source}) async {
    final db = await database;
    if (source == null) return db.query('imported_branches');
    return db.query('imported_branches', where: 'source = ?', whereArgs: [source]);
  }

  /// استيراد مصدر باسمه يحدّث ذلك المصدر وحده، ذرياً، دون مسح المصادر الأخرى.
  Future<void> replaceSourceBranches(String source, List<Branch> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('imported_branches', where: 'source = ?', whereArgs: [source]);
      final batch = txn.batch();
      for (final b in rows) {
        batch.insert('imported_branches', {
          'id': '${source}::${b.id}',
          'source': source,
          'brand': b.brand,
          'name': b.displayName,
          'lat': b.lat,
          'lon': b.lon,
          'region': b.region,
          'city': b.city,
          'district': b.district,
          'address': b.address,
          'verification': b.verification,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> saveSourceMeta(SourceMeta s) async {
    final db = await database;
    await db.insert('sources', {
      'id': s.id,
      'name': s.nameAr,
      'year': s.year,
      'publisher': s.publisher,
      'url': s.url,
      'checked_at': s.checkedAt?.millisecondsSinceEpoch,
      'kind': s.kind.label,
      'coverage': s.coverage,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SourceMeta>> loadSources() async {
    final db = await database;
    final rows = await db.query('sources');
    return rows.map((r) => SourceMeta(
          id: r['id'] as String,
          nameAr: r['name'] as String,
          year: (r['year'] as num?)?.toInt(),
          publisher: (r['publisher'] as String?) ?? '',
          url: (r['url'] as String?) ?? '',
          checkedAt: (r['checked_at'] as num?) != null
              ? DateTime.fromMillisecondsSinceEpoch((r['checked_at'] as num).toInt())
              : null,
          kind: _kindFrom((r['kind'] as String?) ?? ''),
          coverage: (r['coverage'] as String?) ?? 'التغطية غير معروفة',
        )).toList();
  }

  DataClass _kindFrom(String v) {
    if (v.contains('تعداد')) return DataClass.census;
    if (v.contains('تقدير')) return DataClass.estimate;
    if (v.contains('مجتمعي')) return DataClass.community;
    return DataClass.unknown;
  }

  /// نسخة احتياطية قابلة للحفظ عبر منتقي ملفات النظام.
  Future<File> backupTo(File target) async {
    final db = await database;
    await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    final dbPath = db.path;
    return File(dbPath).copy(target.path);
  }
}
