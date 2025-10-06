import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/task_repository.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final TaskRepository _repository = TaskRepository();
  final TextEditingController _textController = TextEditingController();
  
  // Lista temporária APENAS para itens adicionados offline nesta sessão.
  final List<Map<String, dynamic>> _pendingLocalTasks = [];

  @override
  void initState() {
    super.initState();
    // Carrega os itens pendentes de sessões anteriores.
    _loadInitialPendingTasks();
  }

  Future<void> _loadInitialPendingTasks() async {
    final localTasks = await _repository.getLocalUnsyncedTasks();
    if (mounted) {
      setState(() {
        _pendingLocalTasks.addAll(localTasks);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _repository.dispose();
    super.dispose();
  }

  void _addTask() async {
    if (_textController.text.isNotEmpty) {
      final String taskTitle = _textController.text;
      
      // Cria uma representação visual IMEDIATA da tarefa.
      final localTask = {
        'title': taskTitle,
        'isSynced': 0,
      };

      // Adiciona à lista local da UI e chama setState.
      setState(() {
        _pendingLocalTasks.add(localTask);
      });

      _textController.clear();
      
      // Envia para o repositório para salvar e sincronizar em segundo plano.
      await _repository.addTask(taskTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tarefas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(labelText: 'Nova Tarefa'),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addTask,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _repository.getFirestoreTasksStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _pendingLocalTasks.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }
                
                final firestoreTasks = snapshot.data ?? [];
                
                // Combinação Visual: Remove da lista local pendente qualquer item que já chegou do Firestore.
                _pendingLocalTasks.removeWhere((local) {
                  return firestoreTasks.any((remote) => remote['title'] == local['title']);
                });

                final combinedTasks = [...firestoreTasks, ..._pendingLocalTasks];

                if (combinedTasks.isEmpty) {
                  return const Center(child: Text("Nenhuma tarefa."));
                }

                return ListView.builder(
                  itemCount: combinedTasks.length,
                  itemBuilder: (context, index) {
                    final task = combinedTasks[index];
                    final isSynced = task['isSynced'] == 1;
                    return ListTile(
                      title: Text(task['title'].toString()),
                      trailing: Icon(
                        isSynced ? Icons.cloud_done : Icons.cloud_upload_outlined,
                        color: isSynced ? Colors.green : Colors.grey,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}