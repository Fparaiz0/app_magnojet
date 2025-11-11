import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const _databaseName = "Tasks.db";
  static const _databaseVersion = 1;

  static const table = 'tasks';
  static const columnId = 'id'; // ID local
  static const columnFirestoreId =
      'firestoreId'; // ID do documento no Firestore
  static const columnTitle = 'title';
  static const columnIsDone = 'isDone';
  static const columnIsSynced = 'isSynced';

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnFirestoreId TEXT,
        $columnTitle TEXT NOT NULL,
        $columnIsDone INTEGER NOT NULL DEFAULT 0,
        $columnIsSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<int> insert(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    Database db = await instance.database;
    return await db.query(table, orderBy: '$columnId DESC');
  }

  Future<List<Map<String, dynamic>>> queryUnsynced() async {
    Database db = await instance.database;
    return await db.query(table, where: '$columnIsSynced = ?', whereArgs: [0]);
  }

  Future<int> update(Map<String, dynamic> row) async {
    Database db = await instance.database;
    int id = row[columnId];
    return await db.update(table, row, where: '$columnId = ?', whereArgs: [id]);
  }

  Future<void> clearTable() async {
    Database db = await instance.database;
    await db.delete(table);
  }
}
