import { app } from "../src/index";

export default function handler(req: any, res: any) {
  try {
    return app(req, res);
  } catch (err: any) {
    console.error("HANDLER ERROR:", err);
    res.status(500).json({ error: String(err?.message ?? err), stack: err?.stack });
  }
}
