import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/connectivity_service.dart';
import '../services/database_helper.dart';

class TaskRepository {
  final dbHelper = DatabaseHelper.instance;
  final connectivityService = ConnectivityService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  TaskRepository() {
    connectivityService.connectionStatusStream.listen((isConnected) {
      if (isConnected) {
        syncTasks();
      }
    });
  }

  Future<void> addTask(String title) async {
    final row = {
      DatabaseHelper.columnTitle: title,
      DatabaseHelper.columnIsDone: 0,
      DatabaseHelper.columnIsSynced: 0,
    };
    await dbHelper.insert(row);
    syncTasks();
  }

  Stream<List<Map<String, dynamic>>> getFirestoreTasksStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                DatabaseHelper.columnFirestoreId: doc.id,
                DatabaseHelper.columnTitle: data['title'] ?? '',
                DatabaseHelper.columnIsDone: (data['isDone'] ?? false) ? 1 : 0,
                DatabaseHelper.columnIsSynced: 1,

                'userId': data['userId'], 
              };
            }).toList());
  }

  Future<List<Map<String, dynamic>>> getLocalUnsyncedTasks() {
    return dbHelper.queryUnsynced();
  }

  Future<void> syncTasks() async {
    if (!await connectivityService.isConnected()) return;
    final user = _auth.currentUser;
    if (user == null) return;

    final unsyncedTasks = await dbHelper.queryUnsynced();
    if (unsyncedTasks.isEmpty) return;

    final tasksCollection = _firestore.collection('users').doc(user.uid).collection('tasks');
    final writeFutures = <Future<void>>[];
    final idsToDelete = <int>[];

    for (var task in unsyncedTasks) {
      writeFutures.add(tasksCollection.add({
        'title': task[DatabaseHelper.columnTitle],
        'isDone': task[DatabaseHelper.columnIsDone] == 1,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid, 
        'userEmail': user.email, 
      }));
      idsToDelete.add(task[DatabaseHelper.columnId] as int);
    }

    try {
      await Future.wait(writeFutures);
      final db = await dbHelper.database;
      final batch = db.batch();
      for (var id in idsToDelete) {
        batch.delete(DatabaseHelper.table, where: '${DatabaseHelper.columnId} = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print("❌ Erro na sincronização: $e");
    }
  }

  void dispose() {
    connectivityService.dispose();
  }
}
