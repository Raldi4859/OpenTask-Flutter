const express = require('express');
const mysql = require('mysql');
const bodyParser = require('body-parser');
const bcrypt = require('bcrypt');
const fileUpload = require('express-fileupload');

const app = express();
const port = 3000;

const connection = mysql.createConnection({
  host: 'localhost',
  port: 3307,
  user: 'root',
  password: '',
  database: 'opentask',
});

connection.connect((err) => {
  if (err) {
    console.error('Error connecting to MySQL:', err);
    return;
  }
  console.log('Connected to MySQL database');
});

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(fileUpload());

// Set headers to allow cross-origin requests
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization'
  );
  next();
});

app.post('/api/user/authenticate', (req, res) => {
  const email = req.body.email;
  const password = req.body.password;

  const sql = 'SELECT * FROM users WHERE email = ?';
  connection.query(sql, [email], (err, results) => {
    if (err) {
      console.error('Error fetching user data:', err);
      res.status(500).json({ message: 'Failed to authenticate user' });
      return;
    }

    if (results.length === 0) {
      return res.status(401).json({ message: 'Invalid username or password' });
    }

    const user = results[0];
    bcrypt.compare(password, user.password, (err, result) => {
      if (err) {
        console.error('Error comparing passwords:', err);
        res.status(500).json({ message: 'Failed to authenticate user' });
        return;
      }

      if (result) {
        res.json({ message: 'User authenticated' });
      } else {
        res.status(401).json({ message: 'Invalid username or password' });
      }
    });
  });
});

app.post('/api/register', (req, res) => {
  const { email, name, password } = req.body;

  const checkUserQuery = 'SELECT * FROM users WHERE email = ?';
  connection.query(checkUserQuery, [email], (err, result) => {
    if (err) {
      console.error('Failed to execute query:', err);
      return res.status(500).json({ error: 'Internal Server Error' });
    }

    if (result.length > 0) {
      return res.status(409).json({ error: 'User Already Exists' });
    }

    bcrypt.hash(password, 10, (err, hash) => {
      if (err) {
        console.error('Error hashing password:', err);
        return res.status(500).json({ error: 'Internal Server Error' });
      }

      const insertUserQuery = 'INSERT INTO users (email, name, password) VALUES (?, ?, ?)';
      connection.query(insertUserQuery, [email, name, hash], (err) => {
        if (err) {
          console.error('Failed to execute query:', err);
          return res.status(500).json({ error: 'Internal Server Error' });
        }

        return res.json({ message: 'Registration successful' });
      });
    });
  });
});

//Homepage route
app.get('/', (req, res) => {
    // Fetch tasks from the database
    const query = 'SELECT * FROM tasks';
    connection.query(query, (err, results) => {
      if (err) {
        console.error('Error fetching tasks:', err);
        res.status(500).json({ message: 'Failed to fetch tasks' });
        return;
      }
  
      // Render the tasks on the homepage
      res.send(`
        <h1>Task Management App</h1>
        <h2>Tasks:</h2>
        <ul>
          ${results.map((task) => `<li>${task.name}</li>`).join('')}
        </ul>
      `);
    });
  });

app.post('/api/tasks', (req, res) => {
    const { title, description, date, file } = req.body;
  
    const insertTaskQuery =
      'INSERT INTO tasks (title, description, date, file) VALUES (?, ?, ?, ?)';
    connection.query(
      insertTaskQuery,
      [title, description, date, file],
      (err, result) => {
        if (err) {
          console.error('Failed to execute query:', err);
          return res.status(500).json({ error: 'Internal Server Error' });
        }
  
        const taskId = result.insertId;
        return res.status(201).json({ message: 'Task added', taskId });
      }
    );
  });

  
// Upload file
app.post('/tasks/upload', (req, res) => {
    if (!req.files || !req.files.file) {
      res.status(400).json({ message: 'No file uploaded' });
      return;
    }
  
    const file = req.files.file;
    const uploadPath = __dirname + '/uploads/' + file.name; // Specify the upload path on the server
  
    file.mv(uploadPath, (err) => {
      if (err) {
        console.error('Error uploading file:', err);
        res.status(500).json({ message: 'Failed to upload file' });
        return;
      }
  
      // File uploaded successfully
      res.json({ message: 'File uploaded successfully' });
    });
  });

//Delete Task
app.delete('/api/tasks/:id', (req, res) => {
    const taskId = req.params.id;
  
    const deleteTaskQuery = 'DELETE FROM tasks WHERE id = ?';
    connection.query(deleteTaskQuery, [taskId], (err, result) => {
      if (err) {
        console.error('Failed to delete task:', err);
        res.status(500).json({ error: 'Internal Server Error' });
      } else if (result.affectedRows === 0) {
        res.status(404).json({ error: 'Task not found' });
      } else {
        res.json({ message: 'Task deleted successfully' });
      }
    });
  });

app.post('/api/tasks', (req, res) => {
    const { title, description, date, file } = req.body;
  
    const insertTaskQuery = 'INSERT INTO tasks (title, description, date, file) VALUES (?, ?, ?, ?)';
    connection.query(insertTaskQuery, [title, description, date, file], (err, result) => {
      if (err) {
        console.error('Failed to insert task:', err);
        res.status(500).json({ error: 'Failed to insert task' });
        return;
      }
  
      res.status(201).json({ message: 'Task added successfully', taskId: result.insertId });
    });
  });

app.put('/api/tasks/:id', (req, res) => {
    const taskId = req.params.id;
    const { title, description, date } = req.body;
  
    const updateTaskQuery = 'UPDATE tasks SET title = ?, description = ?, date = ? WHERE id = ?';
    connection.query(updateTaskQuery, [title, description, date, taskId], (err, result) => {
      if (err) {
        console.error('Failed to execute query:', err);
        return res.status(500).json({ error: 'Internal Server Error' });
      }
  
      if (result.affectedRows === 0) {
        return res.status(404).json({ error: 'Task not found' });
      }
  
      return res.json({ message: 'Task updated successfully' });
    });
  });

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});

