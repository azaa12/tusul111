const express = require('express');
const bodyParser = require('body-parser');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const cors = require('cors');

const app = express();
const port = 3000;

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'bd2',
  password: '123',
  port: 5432,
});

app.use(cors());
app.use(bodyParser.json());

// Register User
app.post('/api/register', async (req, res) => {
  const { name, email, password, is_driver } = req.body;
  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    await pool.query(
      'INSERT INTO users (name, email, password, is_driver) VALUES ($1, $2, $3, $4)',
      [name, email, hashedPassword, is_driver || false]
    );
    res.status(201).send({ message: 'User registered' });
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Email already in use or registration error' });
  }
});

// Login User
app.post('/api/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    const user = result.rows[0];
    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).send({ error: 'Invalid credentials' });
    }
    res.send({ message: 'Login successful', user: { id: user.id, name: user.name, is_driver: user.is_driver } });
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Login error' });
  }
});

// Get all products
app.get('/api/products', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products ORDER BY id');
    res.send(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Error fetching products' });
  }
});

// Get product by id
app.get('/api/products/:id', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) return res.status(404).send({ error: 'Product not found' });
    res.send(result.rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Error fetching product' });
  }
});

// Add product (for admin or internal use)
app.post('/api/products', async (req, res) => {
  const { title, author, description, price, stock, photo_base64 } = req.body;
  try {
    await pool.query(
      `INSERT INTO products (title, author, description, price, stock, photo_base64)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [title, author, description, price, stock, photo_base64]
    );
    res.status(201).send({ message: 'Product added' });
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Error adding product' });
  }
});

// Update product
app.put('/api/products/:id', async (req, res) => {
  const { title, author, description, price, stock, photo_base64 } = req.body;
  try {
    await pool.query(
      `UPDATE products SET title = $1, author = $2, description = $3, price = $4, stock = $5, photo_base64 = $6 WHERE id = $7`,
      [title, author, description, price, stock, photo_base64, req.params.id]
    );
    res.send({ message: 'Product updated' });
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Error updating product' });
  }
});

// Delete product
app.delete('/api/products/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM products WHERE id = $1', [req.params.id]);
    res.send({ message: 'Product deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Error deleting product' });
  }
});

// Add product to cart
app.post('/api/cart/add', async (req, res) => {
  const { userId, productId, quantity } = req.body;
  if (!userId || !productId) {
    return res.status(400).send({ error: 'Missing userId or productId' });
  }
  try {
    const existing = await pool.query(
      'SELECT * FROM cart_items WHERE user_id = $1 AND product_id = $2',
      [userId, productId]
    );
    if (existing.rows.length > 0) {
      const newQuantity = existing.rows[0].quantity + (quantity || 1);
      await pool.query(
        'UPDATE cart_items SET quantity = $1 WHERE user_id = $2 AND product_id = $3',
        [newQuantity, userId, productId]
      );
    } else {
      await pool.query(
        'INSERT INTO cart_items (user_id, product_id, quantity) VALUES ($1, $2, $3)',
        [userId, productId, quantity || 1]
      );
    }
    res.send({ message: 'Product added to cart' });
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Error adding product to cart' });
  }
});

// Get cart items for user
app.get('/api/cart/:userId', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT ci.quantity, p.* FROM cart_items ci
       JOIN products p ON ci.product_id = p.id
       WHERE ci.user_id = $1`,
      [req.params.userId]
    );
    res.send(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Error fetching cart items' });
  }
});

// Remove product from cart
app.delete('/api/cart/remove', async (req, res) => {
  const { userId, productId } = req.body;
  if (!userId || !productId) {
    return res.status(400).send({ error: 'Missing userId or productId' });
  }
  try {
    await pool.query(
      'DELETE FROM cart_items WHERE user_id = $1 AND product_id = $2',
      [userId, productId]
    );
    res.send({ message: 'Product removed from cart' });
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Error removing product from cart' });
  }
});

// Place order from cart with delivery location
app.post('/api/orders/place', async (req, res) => {
  const { userId, latitude, longitude } = req.body;
  if (!userId || latitude === undefined || longitude === undefined) {
    return res.status(400).send({ error: 'Missing userId or location coordinates' });
  }
  try {
    // Get cart items
    const cartResult = await pool.query(
      `SELECT ci.quantity, p.id, p.price FROM cart_items ci
       JOIN products p ON ci.product_id = p.id
       WHERE ci.user_id = $1`,
      [userId]
    );
    const cartItems = cartResult.rows;
    if (cartItems.length === 0) {
      return res.status(400).send({ error: 'Cart is empty' });
    }
    // Calculate total price
    const total = cartItems.reduce((sum, item) => sum + item.price * item.quantity, 0);

    await pool.query('BEGIN');

    // Insert order
    const orderResult = await pool.query(
      `INSERT INTO orders (user_id, total, latitude, longitude)
       VALUES ($1, $2, $3, $4) RETURNING id`,
      [userId, total, latitude, longitude]
    );
    const orderId = orderResult.rows[0].id;

    // Insert order items
    for (const item of cartItems) {
      await pool.query(
        `INSERT INTO order_items (order_id, product_id, quantity, price)
         VALUES ($1, $2, $3, $4)`,
        [orderId, item.id, item.quantity, item.price]
      );
    }

    // Clear cart
    await pool.query('DELETE FROM cart_items WHERE user_id = $1', [userId]);

    await pool.query('COMMIT');

    res.status(201).send({ message: 'Order placed', orderId });
  } catch (err) {
    await pool.query('ROLLBACK');
    console.error(err);
    res.status(500).send({ error: 'Error placing order' });
  }
});

// Get orders for user with order items
app.get('/api/orders/:userId', async (req, res) => {
  const userId = req.params.userId;
  try {
    const ordersResult = await pool.query(
      'SELECT id, order_date, status, total, latitude, longitude FROM orders WHERE user_id = $1 ORDER BY order_date DESC',
      [userId]
    );
    const orders = ordersResult.rows;

    for (const order of orders) {
      const itemsResult = await pool.query(
        `SELECT oi.quantity, p.title, p.author, p.price, p.photo_base64
         FROM order_items oi
         JOIN products p ON oi.product_id = p.id
         WHERE oi.order_id = $1`,
        [order.id]
      );
      order.items = itemsResult.rows;
    }

    res.send(orders);
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Error fetching orders' });
  }
});

// Get deliveries for driver
app.get('/api/deliveries/driver/:driverId', async (req, res) => {
  try {
    const deliveriesResult = await pool.query(
      `SELECT d.*, o.user_id, o.latitude, o.longitude, o.status as order_status
       FROM deliveries d
       JOIN orders o ON d.order_id = o.id
       WHERE d.driver_id = $1
       ORDER BY d.assigned_at DESC`,
      [req.params.driverId]
    );
    res.send(deliveriesResult.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Error fetching deliveries' });
  }
});

// Driver accepts a delivery
app.post('/api/deliveries/:deliveryId/accept', async (req, res) => {
  const { driverLongitude, driverLatitude } = req.body;
  try {
    await pool.query(
      `UPDATE deliveries
       SET status = 'accepted', driver_longitude = $1, driver_latitude = $2, assigned_at = CURRENT_TIMESTAMP
       WHERE id = $3`,
      [driverLongitude, driverLatitude, req.params.deliveryId]
    );
    res.send({ message: 'Delivery accepted' });
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Error accepting delivery' });
  }
});

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
