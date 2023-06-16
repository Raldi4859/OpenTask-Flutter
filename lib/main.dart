import 'dart:js';
import 'dart:js_util';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mysql1/src/single_connection.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider<UserToken>(
      create: (context) => UserToken(currentUser: User('', '')),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {

  Future<User?> authenticateUser(String email, String password) async {
    Uri url = Uri.parse('http://localhost:3000/api/user/authenticate');

    Map<String, String> headers = {'Content-Type': 'application/json'};
    Map<String, dynamic> body = {'email': email, 'password': password};

    try {
      http.Response response =
          await http.post(url, headers: headers, body: jsonEncode(body));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String userId = responseData['userId'];
        return User(userId, email);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: authenticateUser('email', 'password'), // Authenticate user and retrieve user object
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(); // Show loading indicator while authenticating
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          final currentUser = snapshot.data;
      
    return MaterialApp(
      title: 'Task Management App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/register': (context) => RegistrationScreen(),
       '/home': (context) {
          final User? currentUser = ModalRoute.of(context)?.settings.arguments as User?;
          return HomePageScreen(currentUser: currentUser);
        },
        '/add_task': (context) => AddTaskScreen(currentUser: currentUser!),
          },
        );
       }
      }
    );
  }
}

class User {
  final String id;
  final String email;

  User(this.id, this.email);
}

class UserToken extends ChangeNotifier {
  String token;
  User? currentUser;

  UserToken({this.token = '', required this.currentUser});
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login(BuildContext context) async {
    final String email = _emailController.text;
    final String password = _passwordController.text;
    final String url = 'http://localhost:3000/api/user/authenticate';

    try {
      final response = await http.post(Uri.parse(url), body: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String token = data['token'];

        final userToken = Provider.of<UserToken>(context, listen: false);
        userToken.token = token;

        final userId = data['id'] ?? '';
        final userEmail = data['email'] ?? '';
        final currentUser = User(userId, userEmail);
        userToken.currentUser = currentUser;

        Navigator.pushReplacementNamed(context, '/home', arguments: currentUser);
      } else {
        final data = json.decode(response.body);
        final String message = data['message'];

        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text('Login Failed'),
              content: Text(message),
              actions: <Widget>[
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (error) {
      print('Error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OpenTask'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
              ),
            ),
            SizedBox(height: 16.0),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            SizedBox(height: 24.0),
            ElevatedButton(
              child: Text('Login'),
              onPressed: () {
                _login(context); // Pass the context to the _login method
              },
            ),
            TextButton(
              child: Text('Sign Up'),
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> registerUser() async {
    final url = Uri.parse('http://localhost:3000/api/register');
    final response = await http.post(
      url,
      body: jsonEncode({
        'email': _emailController.text,
        'name': _nameController.text,
        'password': _passwordController.text,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      // Registration successful, handle the response
      print('Registration successful');
    } else {
      // Registration failed, handle the error response
      print('Registration failed: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registration'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter an email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a password';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    registerUser();
                  }
                },
                child: Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class Task {
  final String? id;
  final String name;
  final String description;
  final DateTime dueDate;

  Task({this.id, required this.name, required this.description, required this.dueDate});

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
      dueDate: convertDateFormat(json['dueDate']),
    );
  }
}

  DateTime convertDateFormat(String originalDate) {
  try {
    final dateParts = originalDate.split('-');
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);
    return DateTime(year, month, day);
  } catch (e) {
    print('Failed to parse date: $originalDate');
    // Return current date as a fallback option
    return DateTime.now();
  }
}

class HomePageScreen extends StatefulWidget {
  final User? currentUser;

  HomePageScreen({this.currentUser});

  @override
  _HomePageScreenState createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  List<Task> tasks = [];

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  Future<void> fetchTasks() async {
    final response = await http.get(Uri.parse('http://localhost:3000/tasks'));

    if (response.statusCode == 200) {
      final List<dynamic> taskData = jsonDecode(response.body);
      setState(() {
        tasks = taskData.map((task) => Task.fromJson(task)).toList();
      });
    } else {
      print('Failed to fetch tasks: ${response.statusCode}');
    }
  }

  void deleteTask(BuildContext context, String taskId) async {
    final response = await http.delete(Uri.parse('http://localhost:3000/tasks/$taskId'));

    if (response.statusCode == 200) {
      setState(() {
        tasks.removeWhere((task) => task.id == taskId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task deleted'),
        ),
      );
    } else {
      print('Failed to delete task: ${response.statusCode}');
    }
  }

  Widget buildTaskList() {
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];

        return Container(
          padding: EdgeInsets.all(8.0),
          margin: EdgeInsets.symmetric(vertical: 4.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: ListTile(
            title: Text(task.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.description),
                Text('Due Date: ${DateFormat.yMMMd().format(task.dueDate)}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditTaskScreen(taskId: task.id!),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    deleteTask(context, task.id!);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void logout(BuildContext context) {
    // Perform logout and navigate to login screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Task Management App'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              logout(context);
            },
          ),
        ],
      ),
      body: buildTaskList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddTaskScreen(currentUser: widget.currentUser!)),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class AddTaskScreen extends StatefulWidget {
  final User currentUser;

  AddTaskScreen({required this.currentUser});

  @override
  _AddTaskScreenState createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate; // Initialize with null

  void addTask() async {
    final String name = _nameController.text;
    final String description = _descriptionController.text;
    final String dueDate = _selectedDate?.toString() ?? '';

    final String? userId = widget.currentUser.id; // Fetch user ID from the currently logged-in user

    if (userId != null) {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/tasks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'description': description,
          'due_date': dueDate,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final taskId = responseData['taskId'];

        // Perform any necessary actions after adding the task, such as showing a success message or navigating back to the task list
        print('Task added successfully! Task ID: $taskId');
      } else {
        print('Failed to add task: ${response.statusCode}');
      }
    } else {
      print('User ID not available');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Task'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Task Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a task name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Task Description',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a task description';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              Text(
                'Due Date:',
                style: TextStyle(fontSize: 16.0),
              ),
              SizedBox(height: 8.0),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Select due date',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  ),
                  child: Text(
                    _selectedDate != null ?_selectedDate.toString():'Select due date',
                    style:  TextStyle(fontSize: 16.0),
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  if(_formKey.currentState!.validate()){
                    addTask();
                  }
                },
                child: Text('Add Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}  

class EditTaskScreen extends StatefulWidget {
  final String taskId;

  EditTaskScreen({required this.taskId});

  @override
  _EditTaskScreenState createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  TextEditingController nameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController dueDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTaskDetails();
  }

Future<void> fetchTaskDetails() async {
  final response = await http.get(Uri.parse('http://localhost:3000/tasks/${widget.taskId}'));

  if (response.statusCode == 200) {
    final taskData = jsonDecode(response.body);

    if (taskData['name'] != null) {
      nameController.text = taskData['name'] as String;
    }
    if (taskData['description'] != null) {
      descriptionController.text = taskData['description'] as String;
    }
    if (taskData['dueDate'] != null) {
      dueDateController.text = taskData['dueDate'] as String;
    }
  } else {
    print('Failed to fetch task details: ${response.statusCode}');
  }
}

Future<void> saveTaskDetails(BuildContext context) async {
  final updatedTaskData = {
    'name': nameController.text,
    'description': descriptionController.text,
    'dueDate': dueDateController.text,
  };

  final response = await http.put(
    Uri.parse('http://localhost:3000/tasks/${widget.taskId}'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(updatedTaskData),
  );

  if (response.statusCode == 200) {
    final updatedTask = jsonDecode(response.body);

    setState(() {
      nameController.text = updatedTask['name'] as String;
      descriptionController.text = updatedTask['description'] as String;
      dueDateController.text = updatedTask['dueDate'] as String;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task details saved'),
      ),
    );
  } else {
    print('Failed to save task details: ${response.statusCode}');
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Task'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Name',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Enter task name',
              ),
            ),
            SizedBox(height: 16.0),
            Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                hintText: 'Enter task description',
              ),
            ),
            SizedBox(height: 16.0),
            Text(
              'Due Date',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: dueDateController,
              decoration: InputDecoration(
                hintText: 'Enter task due date',
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                saveTaskDetails(context);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

