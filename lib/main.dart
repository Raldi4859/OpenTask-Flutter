import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Management App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/register': (context) => RegistrationScreen(),
        '/home': (context) => HomePageScreen(),
        '/add_task': (context) => AddTaskScreen(),
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  void loginUser(BuildContext context) async {
    String username = emailController.text;
    String password = passwordController.text;

    bool isAuthenticated = await authenticateUser(username, password);

    if (isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Login Failed'),
            content: Text('Invalid email or password.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  Future<bool> authenticateUser(String email, String password) async {
    Uri url = Uri.parse('http://localhost:3000/api/user/authenticate');

    Map<String, String> headers = {'Content-Type': 'application/json'};
    Map<String, dynamic> body = {'email': email, 'password': password};

    try {
      http.Response response =
          await http.post(url, headers: headers, body: jsonEncode(body));

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
              ),
            ),
            SizedBox(height: 16.0),
            TextFormField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () => loginUser(context),
              child: Text('Login'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              child: Text('Sign Up'),
            )
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

class HomePageScreen extends StatefulWidget {
  @override
  _HomePageScreenState createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  List<String> tasks = [];

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  Future<void> fetchTasks() async {
    try {
      // Fetch tasks from the server
      final response = await http.get(Uri.parse('http://localhost:3000/tasks'));

      if (response.statusCode == 200) {
        final List<dynamic> taskData = jsonDecode(response.body);
        setState(() {
          tasks = taskData.map((task) => task['title'] as String).toList();
        });
      } else {
        print('Failed to fetch tasks: ${response.statusCode}');
      }
    } catch (error) {
      print('Error occurred while fetching tasks: $error');
    }
  }

  void navigateToEditTaskScreen(String taskId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTaskScreen(taskId: taskId),
      ),
    ).then((result) {
      // Refresh the task list if the task was updated
      if (result != null && result) {
        fetchTasks();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('OpenTask'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Tasks:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  title: Text(tasks[index]),
                );
              },
            ),
          ),
          Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              // Navigate to the AddTaskScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTaskScreen(),
                ),
              ).then((result) {
                // Refresh the task list if a new task was added
                if (result != null && result) {
                  fetchTasks();
                }
              });
            },
            child: Text('Add Task'),
          ),
        ),
      ],
    ),
  );
}
}

class AddTaskScreen extends StatefulWidget {
  @override
  _AddTaskScreenState createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now(); // Initialize with current date

  void addTask() async {
    final String name = _nameController.text;
    final String description = _descriptionController.text;
    final String dueDate = _selectedDate?.toString() ?? '';

    final response = await http.post(
      Uri.parse('http://localhost:3000/api/tasks'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'description': description,
        'due_date': dueDate,
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
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime(2030),
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
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Due Date',
                  ),
                  child: Text(
                    _selectedDate != null
                        ? DateFormat('yyyy-MM-dd').format(_selectedDate)
                        : 'Select Date',
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
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
  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTaskDetails();
  }

  Future<void> fetchTaskDetails() async {
    final response = await http.get(
        Uri.parse('http://localhost:3000/tasks/${widget.taskId}'));

    if (response.statusCode == 200) {
      final taskData = jsonDecode(response.body);
      setState(() {
        titleController.text = taskData['title'];
        descriptionController.text = taskData['description'];
        dateController.text = taskData['date'];
      });
    } else {
      print('Failed to fetch task details: ${response.statusCode}');
    }
  }

  void updateTask() async {
    final String url = 'http://localhost:3000/tasks/${widget.taskId}';

    final Map<String, dynamic> taskData = {
      'title': titleController.text,
      'description': descriptionController.text,
      'date': dateController.text,
    };

    final http.Response response = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(taskData),
    );

    if (response.statusCode == 200) {
      Navigator.pop(context, true); // Go back to the previous screen
    } else {
      print('Failed to update task: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Title:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Enter the task title',
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Description:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                hintText: 'Enter the task description',
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Date:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: dateController,
              decoration: InputDecoration(
                hintText: 'Enter the task date',
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: updateTask,
              child: Text('Update Task'),
            ),
          ],
        ),
      ),
    );
  }
}