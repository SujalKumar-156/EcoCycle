// EcoCycle backend: a thin Express API over the MySQL database.
// Design rule: business logic lives in SQL (views, procedures, triggers).
// This file only translates HTTP requests into those SQL calls.
require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');
const path = require('path');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// A pool reuses connections instead of opening a new one per request.
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'EcoCycle',
  waitForConnections: true,
  connectionLimit: 5,
});

// Wraps async handlers so any DB error becomes a JSON response.
// Errors raised by our triggers/procedures (SQLSTATE 45000) reach the
// browser with their MESSAGE_TEXT, so the UI can show them.
const handler = (fn) => (req, res) =>
  fn(req, res).catch((err) => {
    console.error(err.sqlMessage || err.message);
    res.status(err.sqlState ? 400 : 500).json({ error: err.sqlMessage || err.message });
  });

// Validate numeric input before it reaches SQL.
function toInt(value, name) {
  const n = Number(value);
  if (!Number.isInteger(n) || n <= 0) {
    const e = new Error(`${name} must be a positive integer`);
    e.sqlState = 'APP';
    throw e;
  }
  return n;
}

// ---------- Read endpoints (use the views from 04_views_procedures_triggers.sql) ----------
app.get('/api/stats', handler(async (req, res) => {
  const [rows] = await pool.query(
    `SELECT (SELECT COUNT(*) FROM Facilities)         AS facilities,
            (SELECT COUNT(*) FROM Recycling_Batches)  AS batches,
            (SELECT COALESCE(SUM(recovered_weight_kg), 0) FROM Recovered_Materials) AS total_recovered_kg`
  );
  res.json(rows[0]);
}));

app.get('/api/facilities', handler(async (req, res) => {
  const [rows] = await pool.query('SELECT facility_id, facility_name, city FROM Facilities ORDER BY facility_name');
  res.json(rows);
}));

app.get('/api/materials', handler(async (req, res) => {
  const [rows] = await pool.query('SELECT material_id, material_name, unit FROM Materials ORDER BY material_name');
  res.json(rows);
}));

app.get('/api/reports/facility-recovery', handler(async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM vw_facility_recovery ORDER BY total_recovered_kg DESC');
  res.json(rows);
}));

app.get('/api/reports/material-totals', handler(async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM vw_material_totals');
  res.json(rows);
}));

app.get('/api/batches', handler(async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM vw_batch_summary ORDER BY batch_id DESC');
  res.json(rows);
}));

app.get('/api/batches/:id/recoveries', handler(async (req, res) => {
  const id = toInt(req.params.id, 'batch id');
  // "?" placeholders: the driver sends values separately from the SQL text,
  // which is what prevents SQL injection. Never build SQL with string concat.
  const [rows] = await pool.query(
    `SELECT m.material_name, rm.recovered_weight_kg, rm.recorded_at
     FROM Recovered_Materials rm
     JOIN Materials m ON m.material_id = rm.material_id
     WHERE rm.batch_id = ?
     ORDER BY rm.recovered_weight_kg DESC`, [id]);
  res.json(rows);
}));

// ---------- Write endpoints (each one calls a stored procedure) ----------
app.post('/api/batches', handler(async (req, res) => {
  const facilityId = toInt(req.body.facility_id, 'facility_id');
  const code = String(req.body.batch_code || '').trim();
  if (!code) { const e = new Error('batch_code is required'); e.sqlState = 'APP'; throw e; }
  // CALL returns [resultSets..., okPacket]; the first result set holds new_batch_id.
  const [result] = await pool.query('CALL sp_create_batch(?, ?)', [facilityId, code]);
  res.status(201).json({ batch_id: result[0][0].new_batch_id });
}));

app.post('/api/recoveries', handler(async (req, res) => {
  const batchId = toInt(req.body.batch_id, 'batch_id');
  const materialId = toInt(req.body.material_id, 'material_id');
  const weight = Number(req.body.weight);
  if (!(weight > 0)) { const e = new Error('weight must be greater than 0'); e.sqlState = 'APP'; throw e; }
  await pool.query('CALL sp_add_recovered_material(?, ?, ?)', [batchId, materialId, weight]);
  res.status(201).json({ ok: true });
}));

app.post('/api/batches/:id/complete', handler(async (req, res) => {
  const id = toInt(req.params.id, 'batch id');
  await pool.query('CALL sp_complete_batch(?)', [id]);   // transaction lives inside the procedure
  res.json({ ok: true });
}));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`EcoCycle running at http://localhost:${port}`));
