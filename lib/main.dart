import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Starting Firebase initialization...');

  // Initialize Firebase only for supported platforms
  if (kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey:
              'AIzaSyD86V-KWeb8p5DGIE5ArvHXJ4MZJLG77lY', // Fixed to match google-services.json
          appId: '1:176656851950:android:2ca998b8f3594c84f7e4ff',
          messagingSenderId: '176656851950',
          projectId: 'flutter-chata-pp-dc7f4',
          storageBucket:
              'flutter-chata-pp-dc7f4.firebasestorage.app', // Fixed to match google-services.json
        ),
      );
      print('Firebase initialized successfully');
      print('Checking Firestore connection...');
      try {
        // Quick test to check Firestore connection
        final testDoc =
            await FirebaseFirestore.instance
                .collection('test_connection')
                .doc('test')
                .get();
        print(
          'Firestore connection successful: ${testDoc.exists ? 'Document exists' : 'Document does not exist'}',
        );
      } catch (e) {
        print('Firestore connection test failed: $e');
      }
    } catch (e) {
      print('Error initializing Firebase: $e');
    }
  } else {
    print('Platform not supported for Firebase');
  }

  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Todo List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _textController = TextEditingController();
  List<Todo> _todos = [];

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  Future<void> _fetchTodos() async {
    print('Starting to fetch todos...');
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        print('Attempt ${retryCount + 1} to get todos collection...');
        final snapshot = await _firestore.collection('todos').get();
        print(
          'Successfully retrieved snapshot with ${snapshot.docs.length} todos',
        );

        setState(() {
          _todos =
              snapshot.docs.map((doc) {
                final data = doc.data();
                print('Processing todo: ${doc.id} - ${data['title']}');
                return Todo(
                  id: doc.id,
                  title: data['title'] ?? '',
                  isCompleted: data['isCompleted'] ?? false,
                );
              }).toList();
        });
        return; // Success, exit the function
      } catch (e) {
        retryCount++;
        print('Error fetching todos (attempt $retryCount): $e');
        if (retryCount >= maxRetries) {
          // Show error to user only after all retries fail
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error fetching todos after multiple attempts: $e'),
            ),
          );
        } else {
          // Wait before retrying
          await Future.delayed(Duration(seconds: 1));
        }
      }
    }
  }

  Future<void> _addTodo() async {
    try {
      final text = _textController.text.trim();
      if (text.isNotEmpty) {
        final docRef = await _firestore.collection('todos').add({
          'title': text,
          'isCompleted': false,
          'timestamp': FieldValue.serverTimestamp(), // Add timestamp
        });

        print('Document added with ID: ${docRef.id}'); // Debug print

        setState(() {
          _todos.add(Todo(id: docRef.id, title: text, isCompleted: false));
          _textController.clear();
        });
      }
    } catch (e) {
      print('Error adding todo: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding todo: $e')));
    }
  }

  Future<void> _toggleTodoStatus(String id) async {
    final todoIndex = _todos.indexWhere((todo) => todo.id == id);
    if (todoIndex != -1) {
      final updatedTodo = _todos[todoIndex].copyWith(
        isCompleted: !_todos[todoIndex].isCompleted,
      );
      await _firestore.collection('todos').doc(id).update({
        'isCompleted': updatedTodo.isCompleted,
      });
      setState(() {
        _todos[todoIndex] = updatedTodo;
      });
    }
  }

  Future<void> _deleteTodo(String id) async {
    await _firestore.collection('todos').doc(id).delete();
    setState(() {
      _todos.removeWhere((todo) => todo.id == id);
    });
  }

  void _editTodo(String id) {
    final todoIndex = _todos.indexWhere((todo) => todo.id == id);
    if (todoIndex != -1) {
      showDialog(
        context: context,
        builder: (context) {
          final editController = TextEditingController(
            text: _todos[todoIndex].title,
          );
          return AlertDialog(
            title: const Text('Edit Todo'),
            content: TextField(
              controller: editController,
              decoration: const InputDecoration(
                labelText: 'Todo',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final newText = editController.text.trim();
                  if (newText.isNotEmpty) {
                    await _firestore.collection('todos').doc(id).update({
                      'title': newText,
                    });
                    setState(() {
                      _todos[todoIndex] = _todos[todoIndex].copyWith(
                        title: newText,
                      );
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        title: const Text(
          'Todo List',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
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
                    decoration: const InputDecoration(
                      hintText: 'Add a new task...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _addTodo,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _todos.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks yet!',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _todos.length,
                      itemBuilder: (context, index) {
                        final todo = _todos[index];
                        return TodoItem(
                          todo: todo,
                          onToggle: () => _toggleTodoStatus(todo.id),
                          onDelete: () => _deleteTodo(todo.id),
                          onEdit: () => _editTodo(todo.id),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class TodoItem extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const TodoItem({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Checkbox(
          value: todo.isCompleted,
          onChanged: (_) => onToggle(),
          activeColor: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            fontSize: 16,
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted ? Colors.grey : Colors.black87,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              tooltip: 'Edit',
              color: Colors.blue,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
              tooltip: 'Delete',
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

class Todo {
  final String id;
  final String title;
  final bool isCompleted;

  const Todo({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  Todo copyWith({String? title, bool? isCompleted}) {
    return Todo(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
