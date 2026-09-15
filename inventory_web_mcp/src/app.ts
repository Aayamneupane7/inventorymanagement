import express from "express";
import { z } from "zod";

import type { Config } from "./config.js";
import { ErpnextClient, loginToErpnext } from "./erpnext_client.js";
import { SessionStore } from "./session_store.js";

const loginSchema = z.object({ username: z.string().min(1), password: z.string().min(1) });
const scanSchema = z.object({ barcodes: z.array(z.string()).default([]), requestId: z.string().min(1).optional(), disposition: z.enum(["returned", "damaged", "lost"]).optional() });
const rentalSchema = z.object({
  customer: z.string().min(1), startDate: z.string().min(1), endDate: z.string().min(1), notes: z.string().optional(),
  items: z.array(z.object({ line_type: z.enum(["serialized", "qty"]), item_code: z.string().min(1), serial_no: z.string().optional(), qty: z.number().positive() })).min(1),
});
const equipmentSchema = z.object({
  itemCode: z.string().trim().min(1).max(140),
  itemName: z.string().trim().min(1).max(140),
  category: z.string().trim().min(1).max(140),
  trackingMode: z.enum(["serialized", "quantity"]),
  barcode: z.string().trim().min(1).max(140),
  assetId: z.string().trim().max(140).optional(),
  quantity: z.number().positive().optional(),
}).superRefine((value, context) => {
  if (value.trackingMode === "serialized" && !value.assetId) context.addIssue({ code: "custom", message: "assetId is required for serialized equipment", path: ["assetId"] });
  if (value.trackingMode === "quantity" && !value.quantity) context.addIssue({ code: "custom", message: "quantity is required for quantity equipment", path: ["quantity"] });
});

function tokenFrom(request: express.Request) {
  const value = request.header("authorization");
  return value?.startsWith("Bearer ") ? value.substring(7) : undefined;
}

export function createApp(config: Config) {
  const app = express();
  const sessions = new SessionStore(config.sessionSecret, config.sessionTtlSeconds);
  app.use(express.json());
  app.use((_request, response, next) => {
    response.setHeader("Access-Control-Allow-Origin", process.env.CORS_ORIGIN ?? "http://localhost:3000");
    response.setHeader("Access-Control-Allow-Headers", "Authorization, Content-Type");
    response.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    next();
  });
  app.options(/.*/, (_request, response) => response.sendStatus(204));

  const client = (request: express.Request, response: express.Response) => {
    const token = tokenFrom(request);
    const session = token ? sessions.get(token) : undefined;
    if (!session) {
      response.status(401).json({ error: "Sign in is required", code: "unauthenticated" });
      return undefined;
    }
    return new ErpnextClient(config.erpnextUrl, session.sid);
  };
  const upstream = (response: express.Response, error: unknown) => response.status(502).json({ error: error instanceof Error ? error.message : "ERPNext is unavailable", code: "erpnext_unavailable" });
  const operation = async (request: express.Request, response: express.Response, method: string) => {
    const erp = client(request, response); if (!erp) return;
    const parsed = scanSchema.safeParse(request.body);
    if (!parsed.success || !parsed.data.requestId) return response.status(422).json({ error: "barcodes and requestId are required", code: "invalid_request" });
    try { response.json(await erp.callPost(method, { rental: request.params.rental, barcodes: parsed.data.barcodes, request_id: parsed.data.requestId, disposition: parsed.data.disposition })); } catch (error) { upstream(response, error); }
  };

  app.get("/health", (_request, response) => response.json({ status: "ok", service: "inventory-web-mcp" }));
  app.post("/api/v1/auth/login", async (request, response) => {
    const parsed = loginSchema.safeParse(request.body);
    if (!parsed.success) return response.status(422).json({ error: "username and password are required", code: "invalid_request" });
    try { const session = await loginToErpnext(config.erpnextUrl, parsed.data.username, parsed.data.password); response.json({ accessToken: sessions.create(session), user: session.user, expiresIn: config.sessionTtlSeconds }); }
    catch (error) {
      if (error instanceof Error && error.message.includes("ERPNext is unavailable")) return upstream(response, error);
      response.status(401).json({ error: error instanceof Error ? error.message : "Sign-in failed", code: "invalid_credentials" });
    }
  });
  app.get("/api/v1/auth/me", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    try { response.json({ user: await erp.call<string>("frappe.auth.get_logged_user", {}) }); } catch (error) { upstream(response, error); }
  });
  app.post("/api/v1/auth/logout", (request, response) => {
    if (!client(request, response)) return;
    sessions.revoke(tokenFrom(request)!);
    response.sendStatus(204);
  });
  app.get("/api/v1/items", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    try { response.json({ items: await erp.call("lightbenders_warehouse.api.list_inventory", {}) }); } catch (error) { upstream(response, error); }
  });
  app.post("/api/v1/items", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    const parsed = equipmentSchema.safeParse(request.body);
    if (!parsed.success) return response.status(422).json({ error: "Equipment code, name, category, tracking type, and barcode are required", code: "invalid_request" });
    try { response.status(201).json(await erp.callPost("lightbenders_warehouse.api.create_inventory_item", { payload: parsed.data })); } catch (error) { upstream(response, error); }
  });
  app.get("/api/v1/barcodes/:barcode", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    try {
      const result = await erp.call<{ found: boolean; lookup: unknown }>("lightbenders_warehouse.api.find_barcode", { barcode: request.params.barcode });
      if (!result.found) return response.status(404).json({ error: "Barcode not found", code: "not_found" });
      response.json(result.lookup);
    } catch (error) { upstream(response, error); }
  });
  app.post("/api/v1/barcodes/:barcode/register", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    try { response.status(201).json(await erp.callPost("lightbenders_warehouse.api.register_scanned_equipment", { barcode: request.params.barcode })); } catch (error) { upstream(response, error); }
  });
  app.get("/api/v1/customers", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    try { response.json({ customers: await erp.list("Customer", ["name", "customer_name", "customer_type", "mobile_no", "email_id", "disabled"]) }); } catch (error) { upstream(response, error); }
  });
  app.post("/api/v1/customers", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    const name = typeof request.body.customerName === "string" ? request.body.customerName.trim() : "";
    if (!name) return response.status(422).json({ error: "customerName is required", code: "invalid_request" });
    try { response.status(201).json({ customer: await erp.create("Customer", { customer_name: name, customer_type: "Individual", mobile_no: request.body.mobileNo, email_id: request.body.email }) }); } catch (error) { upstream(response, error); }
  });
  app.get("/api/v1/rentals", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    try { response.json({ rentals: await erp.list("Equipment Rental", ["name", "customer", "start_date", "end_date", "status", "docstatus", "modified"]) }); } catch (error) { upstream(response, error); }
  });
  app.get("/api/v1/rentals/:rental", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    try { response.json({ rental: await erp.get("Equipment Rental", request.params.rental) }); } catch (error) { response.status(404).json({ error: "Rental not found", code: "not_found" }); }
  });
  app.post("/api/v1/rentals", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    const parsed = rentalSchema.safeParse(request.body);
    if (!parsed.success) return response.status(422).json({ error: "A customer, dates, and at least one valid line are required", code: "invalid_request" });
    try { response.status(201).json(await erp.callPost("lightbenders_warehouse.api.create_rental", { payload: { customer: parsed.data.customer, start_date: parsed.data.startDate, end_date: parsed.data.endDate, notes: parsed.data.notes, items: parsed.data.items } })); } catch (error) { upstream(response, error); }
  });
  app.post("/api/v1/rentals/:rental/submit", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    try { response.json(await erp.callPost("lightbenders_warehouse.api.submit_rental", { rental: request.params.rental })); } catch (error) { upstream(response, error); }
  });
  app.get("/api/v1/items/:item/serials", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    try { response.json({ serials: await erp.call("lightbenders_warehouse.api.list_available_serials", { item_code: request.params.item }) }); } catch (error) { upstream(response, error); }
  });
  app.get("/api/v1/barcodes/:barcode/active-rentals", async (request, response) => {
    const erp = client(request, response); if (!erp) return;
    try { response.json(await erp.call("lightbenders_warehouse.api.active_rentals_for_barcode", { barcode: request.params.barcode })); } catch (error) { response.status(404).json({ error: "No active rental was found for this barcode", code: "not_found" }); }
  });
  app.post("/api/v1/rentals/:rental/checkout/preview", async (request, response) => { const erp = client(request, response); if (!erp) return; try { response.json(await erp.callPost("lightbenders_warehouse.api.preview_checkout", { rental: request.params.rental, barcodes: request.body.barcodes ?? [] })); } catch (error) { upstream(response, error); } });
  app.post("/api/v1/rentals/:rental/return/preview", async (request, response) => { const erp = client(request, response); if (!erp) return; try { response.json(await erp.callPost("lightbenders_warehouse.api.preview_return", { rental: request.params.rental, barcodes: request.body.barcodes ?? [] })); } catch (error) { upstream(response, error); } });
  app.post("/api/v1/rentals/:rental/checkout/commit", (request, response) => operation(request, response, "lightbenders_warehouse.api.commit_checkout"));
  app.post("/api/v1/rentals/:rental/return/commit", (request, response) => operation(request, response, "lightbenders_warehouse.api.commit_return"));
  return app;
}
