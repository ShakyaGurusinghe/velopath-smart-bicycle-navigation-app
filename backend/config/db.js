// config/db.js
import pkg from "pg";
import dotenv from "dotenv";
<<<<<<< HEAD
=======

dotenv.config();
>>>>>>> e8496efe4f73585abf12bf26b6f29dfc9d3b8b99

const { Pool } = pkg;

const pool = new Pool({
  user: process.env.PGUSER,
  host: process.env.PGHOST,
  database: process.env.PGDATABASE,
  password: process.env.PGPASSWORD,
  port: process.env.PGPORT,
});

pool
  .connect()
  .then((client) => {
    console.log("✅ Connected to PostgreSQL + PostGIS successfully!");
    client.release();
  })
  .catch((err) => {
    console.error("❌ Database connection error:", err.message);
  });

export default pool;