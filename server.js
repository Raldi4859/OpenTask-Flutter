const express = require('express');
const mysql = require('mysql');
const bodyParser = require('body-parser');
const bcrypt = require('bcrypt');
const fileUpload = require('express-fileupload');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

const app = express();
const port = 3000;

const pool = mysql.createPool({
  host: '127.0.0.1',
  port: 3307,
  user: 'root',
  password: '',
  database: 'opentask',
});

pool.getConnection((err, connection) => {
  if (err) {
    console.error('Error connecting to MySQL:', err);
    return;
  }
  console.log('Connected to MySQL database');
  connection.release();
});

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(fileUpload());

// Set headers to allow cross-origin requests
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  next();
});

function generateRandomSecretKey() {
  const secretKey = crypto.randomBytes(32).toString('base64');
  return secretKey;
}

const secretKey = generateRandomSecretKey();
// Authenticate user
app.post('/api/user/authenticate', async (req, res) => {
  const { email, password } = req.body;

  try {
    pool.getConnection((err, connection) => {
      if (err) {
        console.error('Error connecting to MySQL:', err);
        return res.status(500).json({ message: 'Failed to connect to the database' });
      }

      connection.query('SELECT * FROM users WHERE email = ?', [email], (err, results) => {
        connection.release();

        if (err) {
          console.error('Error executing query:', err);
          return res.status(500).json({ message: 'Failed to execute query' });
        }

        if (results.length === 0) {
          return res.status(401).json({ message: 'Authentication failed' });
        }

        const user = results[0];

        bcrypt.compare(password, user.password, (err, result) => {
          if (result) {
            const token = jwt.sign({ userId: user.id, email: user.email }, secretKey);
            return res.status(200).json({ token });
          } else {
            return res.status(401).json({ message: 'Authentication failed' });
          }
        });
      });
    });
  } catch (error) {
    console.log('Error: ', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

// Verify token and fetch user ID
app.post('/api/user/fetchUserId', (req, res) => {
  const token = req.headers.authorization?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  try {
    const decoded = jwt.verify(token, secretKey);
    const userId = decoded.userId;

    return res.status(200).json({ userId });
  } catch (err) {
    return res.status(401).json({ message: 'Unauthorized' });
  }
});

// Login route
app.post('/api/user/login', (req, res) => {
  const { email, password } = req.body;

  // Check if the email and password are provided
  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  // Retrieve the user from the database based on the provided email
  const query = 'SELECT * FROM users WHERE email = ?';
  pool.query(query, [email], (err, results) => {
    if (err) {
      console.error('Error retrieving user from MySQL:', err);
      return res.status(500).json({ error: 'An unexpected error occurred' });
    }

    // Check if the user exists
    if (results.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password'})
    }

    const user = results[0];

    // Compare the provided password with the hashed password stored in the database
    bcrypt.compare(password, user.password, (err, isMatch) => {
      if (err) {
        console.error('Error comparing passwords:', err);
        return res.status(500).json({ error: 'An unexpected error occurred' });
      }

      if (!isMatch) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      // Generate a JWT token
      const token = jwt.sign({ userId: user.id }, 'secret');

      res.json({ token });
    });
  });
});

//Route Register
app.post('/api/register', (req, res) => {
  const { email, name, password } = req.body;

  const checkUserQuery = 'SELECT * FROM users WHERE email = ?';
  pool.query(checkUserQuery, [email], (err, result) => {
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
      pool.query(insertUserQuery, [email, name, hash], (err) => {
        if (err) {
          console.error('Failed to execute query:', err);
          return res.status(500).json({ error: 'Internal Server Error' });
        }

        return res.json({ message: 'Registration successful' });
      });
    });
  });
});

// Homepage route
app.get('/tasks', (req, res) => {
  // Fetch tasks from the database
  const query = 'SELECT name, description, due_date FROM tasks'; // Select name, description, and due_date
  pool.query(query, (err, results) => {
    if (err) {
      console.error('Error fetching tasks:', err);
      res.status(500).json({ message: 'Failed to fetch tasks' });
      return;
    }

    // Extract relevant task information and send as response
    const tasks = results.map((task) => ({
      name: task.name.toString(),
      description: task.description.toString(),
      dueDate: task.due_date.toString(),
    }));

    res.json(tasks);
  });
});

//Route Add Task
app.post('/api/tasks', (req, res) => {
  const { name, description, due_date, filename } = req.body;

  const insertTaskQuery =
    'INSERT INTO tasks (name, description, due_date, filename) VALUES (?, ?, ?, ?)';
  pool.query(
    insertTaskQuery,
    [name, description, due_date, filename],
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
    res.status(400).json({ message: 'No file' })
  if (!req.files || !req.files.file) {
    res.status(400).json({ message: 'No file uploaded' });
    return;
  }}

  const file = req.files.file;

  // Move the uploaded file to the desired location
  const uploadPath = __dirname + '/uploads/' + file.name;
  file.mv(uploadPath, (err) => {
    if (err) {
      console.error('Error uploading file:', err);
      res.status(500).json({ message: 'Failed to upload file' });
      return;
    }

    res.json({ message: 'File uploaded successfully', filename: file.name });
  });
});

app.get('/tasks/:id', (req, res) => {
  const taskId = req.params.id;
  
  // Fetch the task from the database based on the ID
  const query = `SELECT * FROM tasks WHERE id = ${taskId}`;
  pool.query(query, (err, results) => {
    if (err) {
      console.error('Error fetching task:', err);
      res.status(500).json({ message: 'Failed to fetch task' });
      return;
    }
    
    // Check if the task with the given ID exists
    if (results.length === 0) {
      res.status(404).json({ message: 'Task not found' });
      return;
    }
    
    const task = results[0];
    res.json(task);
  });
});

app.put('/tasks/:id', (req, res) => {
  const taskId = req.params.id;
  const { name, description, dueDate } = req.body;
  
  // Update the task in the database based on the ID
  const query = `UPDATE tasks SET name = '${name}', description = '${description}', dueDate = '${dueDate}' WHERE id = ${taskId}`;
  pool.query(query, (err, results) => {
    if (err) {
      console.error('Error updating task:', err);
      res.status(500).json({ message: 'Failed to update task' });
      return;
    }
    
    // Fetch the updated task from the database
    const fetchQuery = `SELECT * FROM tasks WHERE id = ${taskId}`;
    pool.query(fetchQuery, (fetchErr, fetchResults) => {
      if (fetchErr) {
        console.error('Error fetching updated task:', fetchErr);
        res.status(500).json({ message: 'Failed to fetch updated task' });
        return;
      }
      
      const updatedTask = fetchResults[0];
      res.json(updatedTask);
    });
  });
});

app.delete('/tasks/:taskId', (req, res) => {
  const { taskId } = req.params;

  // Delete task from the database using the task ID
  const query = `DELETE FROM tasks WHERE id = '${taskId}'`;
  pool.query(query, (err, results) => {
    if (err) {
      console.error('Error deleting task:', err);
      res.status(500).json({ message: 'Failed to delete task' });
      return;
    }

    res.json({ message: 'Task deleted successfully' });
  });
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
