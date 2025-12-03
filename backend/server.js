// server.js
import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import testRoutes from "./routes/testRoutes.js";
import routingRoutes from "./routes/routingRoutes.js"; // ✅ for /api/routing/generate
import pgRoutingRoutes from "./routes/routing.js";      // ✅ for /api/routing/route

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

<<<<<<< HEAD
// API routes
=======
// Health check / DB test
>>>>>>> e8496efe4f73585abf12bf26b6f29dfc9d3b8b99
app.use("/api", testRoutes);

// Multi-objective route list (generate best segments)
app.use("/api/routing", routingRoutes);

// pgRouting-based full path calculation
app.use("/api/pg-routing", pgRoutingRoutes);


const PORT = process.env.PORT || 5001;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
