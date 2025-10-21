// routes/testRoutes.js
import express from "express";
import { testDatabase } from "../controllers/testController.js";

const router = express.Router();

router.get("/test-db", testDatabase);

export default router;
