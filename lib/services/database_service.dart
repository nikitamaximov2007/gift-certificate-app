import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/certificate_record.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final path = p.join(await getDatabasesPath(), 'certificates.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE certificates (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name TEXT    NOT NULL,
            amount    REAL    NOT NULL,
            season    TEXT    NOT NULL,
            created_at TEXT   NOT NULL,
            file_path TEXT    NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> addRecord(CertificateRecord record) async {
    return await _db!.insert('certificates', record.toMap());
  }

  Future<List<CertificateRecord>> fetchAll() async {
    final rows = await _db!.query('certificates', orderBy: 'id DESC');
    return rows.map(CertificateRecord.fromMap).toList();
  }

  Future<void> deleteRecord(int id) async {
    await _db!.delete('certificates', where: 'id = ?', whereArgs: [id]);
  }
}
