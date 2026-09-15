"""Import approved inventory rows into a disposable ERPNext site.

The JSON is generated locally from the approved workbook so this Frappe app
does not need a spreadsheet dependency in production.
"""

from __future__ import annotations

import json
from collections import defaultdict

import frappe
from frappe.utils import getdate

from lightbenders_warehouse.services.rental_availability import get_rental_warehouse, resolve_company

INITIAL_IMPORT_REMARKS = "Initial Lightblenders inventory import"


def import_file(path: str) -> dict:
	with open(path, encoding="utf-8") as source:
		return import_rows(json.load(source))


def import_rows(rows: list[dict]) -> dict:
	company = resolve_company()
	if frappe.db.exists(
		"Stock Entry",
		{"stock_entry_type": "Material Receipt", "remarks": INITIAL_IMPORT_REMARKS, "docstatus": 1},
	):
		return {"already_imported": True}
	_ensure_fiscal_year(company)
	warehouse = get_rental_warehouse(company)
	by_product: dict[str, list[dict]] = defaultdict(list)
	for row in rows:
		by_product[row["product_code"]].append(row)

	serials_by_item: dict[str, list[str]] = defaultdict(list)
	qty_by_item: dict[str, float] = defaultdict(float)
	for code, records in by_product.items():
		first = records[0]
		_ensure_group(first["category"])
		if not frappe.db.exists("Item", code):
			frappe.get_doc({
				"doctype": "Item", "item_code": code, "item_name": first["equipment_name"],
				"item_group": first["category"], "stock_uom": "Nos",
				"is_stock_item": 1, "maintain_stock": 1,
				"has_serial_no": first["tracking_mode"] == "SERIALIZED",
				"barcodes": [] if first["tracking_mode"] == "SERIALIZED" else [
					{"barcode": first["barcode_payload"]}
				],
			}).insert(ignore_permissions=True)
		if first["tracking_mode"] == "SERIALIZED":
			for row in records:
				serial = row["asset_id"]
				if not frappe.db.exists("Serial No", serial):
					frappe.get_doc({"doctype": "Serial No", "serial_no": serial, "item_code": code,
						"company": company, "barcode_payload": row["barcode_payload"]}).insert(ignore_permissions=True)
				serials_by_item[code].append(serial)
		else:
			qty_by_item[code] += float(first["quantity"])

	items = [
		{"item_code": code, "qty": len(serials), "t_warehouse": warehouse,
		 "use_serial_batch_fields": 1, "serial_no": "\n".join(serials), "allow_zero_valuation_rate": 1}
		for code, serials in serials_by_item.items()
	] + [
		{"item_code": code, "qty": qty, "t_warehouse": warehouse, "allow_zero_valuation_rate": 1}
		for code, qty in qty_by_item.items()
	]
	if items:
		doc = frappe.get_doc({"doctype": "Stock Entry", "stock_entry_type": "Material Receipt",
			"company": company, "to_warehouse": warehouse, "remarks": INITIAL_IMPORT_REMARKS, "items": items})
		doc.insert(ignore_permissions=True)
		doc.submit()
	return {"products": len(by_product), "serialized_assets": sum(map(len, serials_by_item.values())), "quantity_items": len(qty_by_item)}


def _ensure_group(name: str) -> None:
	if frappe.db.exists("Item Group", name):
		return
	if not frappe.db.exists("Item Group", "All Item Groups"):
		frappe.get_doc({"doctype": "Item Group", "item_group_name": "All Item Groups", "is_group": 1}).insert(ignore_permissions=True)
	frappe.get_doc({"doctype": "Item Group", "item_group_name": name, "parent_item_group": "All Item Groups", "is_group": 0}).insert(ignore_permissions=True)


def _ensure_fiscal_year(company: str) -> None:
	date = getdate()
	if frappe.db.exists("Fiscal Year", {"year_start_date": ("<=", date), "year_end_date": (">=", date)}):
		return
	frappe.get_doc({
		"doctype": "Fiscal Year",
		"year": str(date.year),
		"year_start_date": f"{date.year}-01-01",
		"year_end_date": f"{date.year}-12-31",
		"companies": [{"company": company}],
	}).insert(ignore_permissions=True)
