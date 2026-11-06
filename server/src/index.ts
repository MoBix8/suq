import cors from "cors";
import express from "express";
import helmet from "helmet";
import morgan from "morgan";
import { env } from "./env";
import { errorHandler, notFound } from "./errors";
import { entitlementPublicKeyBase64 } from "./lib/entitlement";
import { adminRouter } from "./routes/admin";
import { authRouter } from "./routes/auth";
import { billingRouter } from "./routes/billing";
import { catalogRouter } from "./routes/catalog";
import { publicRouter } from "./routes/public";
import { exportImportRouter } from "./routes/exportImport";
import { syncRouter } from "./routes/sync";

export const app = express();

app.use(helmet());
app.use(
  cors({
    origin:
      env.corsOrigin === "*"
        ? true
        : env.corsOrigin.split(",").map((value) => value.trim()),
  }),
);
app.use(express.json({ limit: "5mb" }));
app.use(morgan(process.env.NODE_ENV === "production" ? "combined" : "dev"));

app.get("/api/health", (_req, res) => {
  res.json({
    ok: true,
    service: "suq-api",
    serverTime: new Date().toISOString(),
    entitlementPublicKey: entitlementPublicKeyBase64(),
  });
});

app.use("/api", publicRouter);
app.use("/api/auth", authRouter);
app.use("/api", catalogRouter);
app.use("/api", billingRouter);
app.use("/api", syncRouter);
app.use("/api/admin", adminRouter);
app.use("/api/admin", exportImportRouter);

app.use(notFound);
app.use(errorHandler);

// Only listen when run directly (local dev). On Vercel/serverless, the app
// is exported and invoked by the platform.
if (require.main === module) {
  app.listen(env.port, () => {
    console.log(`SUQ API listening on http://localhost:${env.port}`);
    console.log(`Entitlement public key: ${entitlementPublicKeyBase64()}`);
  });
}
