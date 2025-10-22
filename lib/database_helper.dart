import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models/folder.dart';
import 'models/card_model.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;
  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _open('cards.db');
    return _db!;
  }

  Future<Database> _open(String fileName) async {
    final base = await getDatabasesPath();
    final path = join(base, fileName);
    return openDatabase(path, version: 1, onCreate: _create);
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        createdAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE cards(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        suit TEXT NOT NULL,
        imageUrl TEXT,
        folderId INTEGER NOT NULL,
        FOREIGN KEY(folderId) REFERENCES folders(id) ON DELETE CASCADE
      );
    ''');

    // seed 4 folders
    for (final suit in const ['Hearts','Spades','Diamonds','Clubs']) {
      await db.insert('folders', {
        'name': suit,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  // ---------- FOLDERS ----------
  Future<List<Folder>> getFolders() async {
    final d = await db;
    final rows = await d.query('folders', orderBy: 'name ASC');
    return rows.map(Folder.fromJson).toList();
  }

  Future<int> cardCountInFolder(int folderId) async {
    final d = await db;
    final r = await d.rawQuery('SELECT COUNT(*) c FROM cards WHERE folderId=?', [folderId]);
    return (r.first['c'] as int?) ?? 0;
  }

  Future<CardModel?> firstCardInFolder(int folderId) async {
    final d = await db;
    final rows = await d.query('cards',
        where: 'folderId=?',
        whereArgs: [folderId],
        orderBy: 'id ASC',
        limit: 1);
    if (rows.isEmpty) return null;
    return CardModel.fromJson(rows.first);
  }

  // ---------- CARDS ----------
  Future<List<CardModel>> getCardsByFolder(int folderId) async {
    final d = await db;
    final rows = await d.query('cards',
        where: 'folderId=?', whereArgs: [folderId], orderBy: 'id DESC');
    return rows.map(CardModel.fromJson).toList();
  }

  Future<int> addCard(CardModel card) async {
    final d = await db;
    // enforce folder limit: max 6
    final count = await cardCountInFolder(card.folderId);
    if (count >= 6) {
      throw StateError('Folder can only hold up to 6 cards.');
    }
    return d.insert('cards', card.toJson());
  }

  Future<int> updateCard(CardModel card) async {
    final d = await db;
    return d.update('cards', card.toJson(), where: 'id=?', whereArgs: [card.id]);
  }

  Future<int> deleteCard(int id) async {
    final d = await db;
    return d.delete('cards', where: 'id=?', whereArgs: [id]);
  }
}
