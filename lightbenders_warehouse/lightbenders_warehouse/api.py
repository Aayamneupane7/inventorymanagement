"""Public inventory-rental service methods used only by the web gateway."""

from __future__ import annotations

import hashlib

import frappe
from frappe import _
from frappe.utils import flt

from lightbenders_warehouse.services.rental_availability import get_rental_warehouse, resolve_company


def _as_list(value):
	return frappe.parse_json(value) if isinstance(value, str) else (value or [])


def _rental(name):
	doc = frappe.get_doc("Equipment Rental", name)
	if doc.docstatus != 1:
		frappe.throw(_("Rental {0} must be submitted first.").format(name))
	return doc


def _manifest(rental, barcodes):
	doc = _rental(rental)
	expected_serials = {row.serial_no for row in doc.items if row.line_type == "serialized" and row.serial_no}
	expected_qty = {}
	for row in doc.items:
		if row.line_type == "qty":
			expected_qty[row.item_code] = expected_qty.get(row.item_code, 0) + flt(row.qty)
	# A return manifest is always measured against what remains checked out.  This
	# prevents a second scan of an already-returned item from creating a duplicate
	# Stock Entry (or taking quantity below zero in Rented Out).
	operations = frappe.get_all(
		"Rental Inventory Operation",
		filters={"rental": doc.name, "operation_type": "return"},
		pluck="name",
	)
	if operations:
		for row in frappe.get_all(
			"Rental Inventory Operation Item",
			filters={"parent": ("in", operations)},
			fields=["serial_no", "item_code", "qty"],
		):
			if row.serial_no:
				expected_serials.discard(row.serial_no)
			else:
				expected_qty[row.item_code] = max(
				0, expected_qty.get(row.item_code, 0) - flt(row.qty)
			)
	scanned_serials, scanned_qty, unknown, duplicates = set(), {}, [], []
	for raw in _as_list(barcodes):
		barcode = str(raw).strip()
		if not barcode:
			continue
		serial = frappe.db.get_value("Serial No", {"barcode_payload": barcode}, "name")
		if serial:
			if serial in scanned_serials:
				duplicates.append(barcode)
			else:
				scanned_serials.add(serial)
			continue
		item = frappe.db.get_value("Item Barcode", {"barcode": barcode}, "parent")
		if item:
			scanned_qty[item] = scanned_qty.get(item, 0) + 1
		else:
			unknown.append(barcode)
	return {"doc": doc, "expected_serials": expected_serials, "expected_qty": expected_qty,
		"scanned_serials": scanned_serials, "scanned_qty": scanned_qty, "unknown": unknown, "duplicates": duplicates}


def _preview(manifest, exact):
	expected, scanned = manifest["expected_serials"], manifest["scanned_serials"]
	expected_qty, scanned_qty = manifest["expected_qty"], manifest["scanned_qty"]
	unexpected_qty = {item: qty for item, qty in scanned_qty.items() if item not in expected_qty or qty > expected_qty[item]}
	missing_qty = {item: qty - scanned_qty.get(item, 0) for item, qty in expected_qty.items() if qty > scanned_qty.get(item, 0)}
	invalid = bool(scanned - expected or manifest["unknown"] or manifest["duplicates"] or unexpected_qty)
	complete = not (invalid or expected - scanned or missing_qty)
	return {"rental": manifest["doc"].name, "expected": sorted(expected), "scanned": sorted(scanned),
		"missing": sorted(expected - scanned), "unexpected": sorted(scanned - expected),
		"expected_qty": expected_qty, "scanned_qty": scanned_qty, "missing_qty": missing_qty,
		"unexpected_qty": unexpected_qty, "unknown": manifest["unknown"], "duplicate": manifest["duplicates"],
		"complete": complete if exact else not invalid}


def _barcode_lookup(barcode: str) -> dict | None:
	barcode = (barcode or "").strip()
	if not barcode:
		frappe.throw(_("Barcode is required."))
	serial = frappe.db.get_value("Serial No", {"barcode_payload": barcode}, ["name", "item_code", "warehouse", "status"], as_dict=True)
	if serial:
		return {"type": "serialized", "barcode": barcode, "serial": serial}
	item_barcode = frappe.db.get_value("Item Barcode", {"barcode": barcode}, ["parent"], as_dict=True)
	if item_barcode:
		item = frappe.db.get_value("Item", item_barcode.parent, ["item_code", "item_name"], as_dict=True)
		return {"type": "quantity", "barcode": barcode, "item": item}
	return None


@frappe.whitelist()
def lookup_barcode(barcode: str) -> dict:
	lookup = _barcode_lookup(barcode)
	if lookup:
		return lookup
	barcode = (barcode or "").strip()
	frappe.throw(_("Barcode {0} was not found.").format(barcode), frappe.DoesNotExistError)


@frappe.whitelist()
def find_barcode(barcode: str) -> dict:
	"""Return an explicit miss so the gateway never confuses it with an ERP error."""
	lookup = _barcode_lookup(barcode)
	return {"found": bool(lookup), "lookup": lookup}


def _ensure_item_group(name: str) -> None:
	if frappe.db.exists("Item Group", name):
		return
	if not frappe.db.exists("Item Group", "All Item Groups"):
		frappe.get_doc({"doctype": "Item Group", "item_group_name": "All Item Groups", "is_group": 1}).insert()
	frappe.get_doc({"doctype": "Item Group", "item_group_name": name, "parent_item_group": "All Item Groups", "is_group": 0}).insert()


@frappe.whitelist()
def create_inventory_item(payload: dict | str) -> dict:
	"""Register physical equipment from the web and receive it into the rental store."""
	payload = frappe.parse_json(payload) if isinstance(payload, str) else payload
	item_code = (payload.get("itemCode") or "").strip()
	item_name = (payload.get("itemName") or "").strip()
	category = (payload.get("category") or "").strip()
	tracking_mode = payload.get("trackingMode")
	barcode = (payload.get("barcode") or "").strip()
	asset_id = (payload.get("assetId") or "").strip()
	quantity = flt(payload.get("quantity"))
	if not all([item_code, item_name, category, barcode]) or tracking_mode not in {"serialized", "quantity"}:
		frappe.throw(_("Equipment code, name, category, tracking type, and barcode are required."))
	if tracking_mode == "serialized" and not asset_id:
		frappe.throw(_("Asset ID is required for serialized equipment."))
	if tracking_mode == "quantity" and quantity <= 0:
		frappe.throw(_("Quantity must be greater than zero."))
	if frappe.db.exists("Serial No", {"barcode_payload": barcode}) or frappe.db.exists("Item Barcode", {"barcode": barcode}):
		frappe.throw(_("Barcode {0} is already registered.").format(barcode))

	company = resolve_company()
	warehouse = get_rental_warehouse(company)
	item = frappe.db.exists("Item", item_code)
	if not item:
		_ensure_item_group(category)
		frappe.get_doc({
			"doctype": "Item", "item_code": item_code, "item_name": item_name,
			"item_group": category, "stock_uom": "Nos", "is_stock_item": 1,
			"maintain_stock": 1, "has_serial_no": tracking_mode == "serialized",
			"barcodes": [] if tracking_mode == "serialized" else [{"barcode": barcode}],
		}).insert()
	else:
		has_serial = bool(frappe.db.get_value("Item", item_code, "has_serial_no"))
		if has_serial != (tracking_mode == "serialized"):
			frappe.throw(_("The selected item has a different tracking type."))
		if tracking_mode == "quantity":
			item_doc = frappe.get_doc("Item", item_code)
			item_doc.append("barcodes", {"barcode": barcode})
			item_doc.save()

	if tracking_mode == "serialized":
		if frappe.db.exists("Serial No", asset_id):
			frappe.throw(_("Asset ID {0} is already registered.").format(asset_id))
		frappe.get_doc({"doctype": "Serial No", "serial_no": asset_id, "item_code": item_code,
			"company": company, "barcode_payload": barcode}).insert()
		items = [{"item_code": item_code, "qty": 1, "t_warehouse": warehouse,
			"use_serial_batch_fields": 1, "serial_no": asset_id, "allow_zero_valuation_rate": 1}]
	else:
		items = [{"item_code": item_code, "qty": quantity, "t_warehouse": warehouse,
			"allow_zero_valuation_rate": 1}]
	entry = frappe.get_doc({"doctype": "Stock Entry", "stock_entry_type": "Material Receipt",
		"company": company, "to_warehouse": warehouse,
		"remarks": _("Equipment added from web: {0}").format(barcode), "items": items})
	entry.insert()
	entry.submit()
	return {"item_code": item_code, "stock_entry": entry.name, "lookup": lookup_barcode(barcode)}


@frappe.whitelist()
def register_scanned_equipment(barcode: str) -> dict:
	"""Create a minimal serialized asset for a previously unseen physical barcode."""
	barcode = (barcode or "").strip()
	if not barcode:
		frappe.throw(_("Barcode is required."))
	existing = _barcode_lookup(barcode)
	if existing:
		return {"created": False, "lookup": existing}
	identifier = f"AUTO-{hashlib.sha1(barcode.encode()).hexdigest()[:12].upper()}"
	result = create_inventory_item({
		"itemCode": identifier,
		"itemName": f"Unregistered equipment {identifier}",
		"category": "Unregistered Equipment",
		"trackingMode": "serialized",
		"barcode": barcode,
		"assetId": identifier,
	})
	return {"created": True, **result}


@frappe.whitelist()
def create_rental(payload: dict | str) -> dict:
	"""Create a draft rental. Submission remains explicit so staff can review it."""
	payload = frappe.parse_json(payload) if isinstance(payload, str) else payload
	if not payload or not payload.get("customer") or not payload.get("start_date") or not payload.get("end_date"):
		frappe.throw(_("Customer, start date, and end date are required."))
	items = payload.get("items") or []
	if not items:
		frappe.throw(_("Add at least one rental line."))
	doc = frappe.get_doc({
		"doctype": "Equipment Rental",
		"naming_series": "RENT-.YYYY.-",
		"customer": payload["customer"],
		"start_date": payload["start_date"],
		"end_date": payload["end_date"],
		"notes": payload.get("notes"),
		"items": items,
	})
	doc.insert()
	return {"rental": doc.as_dict()}


@frappe.whitelist()
def submit_rental(rental: str) -> dict:
	doc = frappe.get_doc("Equipment Rental", rental)
	if doc.docstatus != 0:
		frappe.throw(_("Only draft rentals can be submitted."))
	doc.submit()
	return {"rental": doc.as_dict()}


@frappe.whitelist()
def list_available_serials(item_code: str) -> list[dict]:
	"""Explicit selection list; this deliberately does not recommend rental items."""
	if not item_code:
		frappe.throw(_("Item is required."))
	return frappe.get_all(
		"Serial No",
		filters={"item_code": item_code, "warehouse": get_rental_warehouse()},
		fields=["name", "barcode_payload"],
		order_by="name",
	)


@frappe.whitelist()
def list_inventory() -> list[dict]:
	"""Return the complete rentable catalogue with current store-floor stock."""
	warehouse = get_rental_warehouse()
	stock_by_item = {
		row.item_code: flt(row.actual_qty)
		for row in frappe.get_all(
			"Bin", filters={"warehouse": warehouse}, fields=["item_code", "actual_qty"]
		)
	}
	items = frappe.get_all(
		"Item",
		fields=["name", "item_code", "item_name", "item_group", "has_serial_no", "disabled"],
		limit_page_length=0,
	)
	for item in items:
		item["actual_qty"] = stock_by_item.get(item.item_code, 0)
	return items


@frappe.whitelist()
def active_rentals_for_barcode(barcode: str) -> dict:
	"""Find the checked-out rental(s) that can receive a scanned return."""
	lookup = lookup_barcode(barcode)
	serial_no = lookup.get("serial", {}).get("name")
	item_code = lookup.get("item", {}).get("item_code") or lookup.get("serial", {}).get("item_code")
	rental_names = frappe.get_all(
		"Equipment Rental",
		filters={"docstatus": 1, "status": ("in", ["Active", "Partially Returned", "Overdue"])},
		fields=["name", "customer", "status", "end_date"],
	)
	matches = []
	for rental in rental_names:
		filters = {"parent": rental.name, "parenttype": "Equipment Rental", "item_code": item_code}
		if serial_no:
			filters["serial_no"] = serial_no
		if frappe.db.exists("Equipment Rental Item", filters):
			matches.append(rental)
	return {"barcode": barcode, "lookup": lookup, "rentals": matches}


@frappe.whitelist()
def preview_checkout(rental: str, barcodes: list[str] | str) -> dict:
	return _preview(_manifest(rental, barcodes), True)


def _operation_items(manifest, disposition=None):
	items = [{"item_code": frappe.db.get_value("Serial No", serial, "item_code"), "serial_no": serial, "qty": 1, "disposition": disposition} for serial in sorted(manifest["scanned_serials"])]
	items.extend({"item_code": item, "qty": qty, "disposition": disposition} for item, qty in manifest["scanned_qty"].items())
	return items


def _stock_entry(company, source, destination, manifest, remarks):
	by_item = {}
	for serial in manifest["scanned_serials"]:
		item = frappe.db.get_value("Serial No", serial, "item_code")
		by_item.setdefault(item, {"serials": [], "qty": 0})["serials"].append(serial)
	for item, qty in manifest["scanned_qty"].items():
		by_item.setdefault(item, {"serials": [], "qty": 0})["qty"] += qty
	items = []
	for item, allocation in by_item.items():
		if allocation["serials"]:
			items.append({"item_code": item, "qty": len(allocation["serials"]), "s_warehouse": source, "t_warehouse": destination, "use_serial_batch_fields": 1, "serial_no": "\n".join(allocation["serials"]), "allow_zero_valuation_rate": 1})
		if allocation["qty"]:
			items.append({"item_code": item, "qty": allocation["qty"], "s_warehouse": source, "t_warehouse": destination, "allow_zero_valuation_rate": 1})
	doc = frappe.get_doc({"doctype": "Stock Entry", "stock_entry_type": "Material Transfer", "company": company, "remarks": remarks, "items": items})
	doc.insert()
	doc.submit()
	return doc


def _existing_operation(rental, request_id):
	return frappe.db.get_value("Rental Inventory Operation", {"rental": rental, "request_id": request_id}, "name")


@frappe.whitelist()
def commit_checkout(rental: str, barcodes: list[str] | str, request_id: str) -> dict:
	if not request_id:
		frappe.throw(_("request_id is required."))
	existing = _existing_operation(rental, request_id)
	if existing:
		return {"operation": existing, "idempotent": True}
	manifest = _manifest(rental, barcodes)
	if manifest["doc"].status != "Reserved" or not _preview(manifest, True)["complete"]:
		frappe.throw(_("Checkout requires a Reserved rental and an exact scan manifest."))
	company = resolve_company()
	entry = _stock_entry(company, get_rental_warehouse(company), _ensure_warehouse("Rented Out", company), manifest, f"Rental checkout {rental} / {request_id}")
	operation = frappe.get_doc({"doctype": "Rental Inventory Operation", "rental": rental, "operation_type": "checkout", "request_id": request_id, "stock_entry": entry.name, "items": _operation_items(manifest)}).insert()
	manifest["doc"].db_set("status", "Active", update_modified=True)
	return {"operation": operation.name, "stock_entry": entry.name, "idempotent": False}


@frappe.whitelist()
def preview_return(rental: str, barcodes: list[str] | str) -> dict:
	manifest = _manifest(rental, barcodes)
	if manifest["doc"].status not in ("Active", "Partially Returned", "Overdue"):
		frappe.throw(_("Only checked-out rentals can be returned."))
	return _preview(manifest, False)


@frappe.whitelist()
def commit_return(rental: str, barcodes: list[str] | str, disposition: str, request_id: str) -> dict:
	if disposition not in {"returned", "damaged", "lost"} or not request_id:
		frappe.throw(_("A valid disposition and request_id are required."))
	existing = _existing_operation(rental, request_id)
	if existing:
		return {"operation": existing, "idempotent": True}
	manifest = _manifest(rental, barcodes)
	preview = _preview(manifest, False)
	if manifest["doc"].status not in ("Active", "Partially Returned", "Overdue") or not _operation_items(manifest) or not preview["complete"]:
		frappe.throw(_("Return manifest contains invalid scans."))
	company = resolve_company()
	destination = get_rental_warehouse(company) if disposition == "returned" else _ensure_warehouse("Maintenance" if disposition == "damaged" else "Lost", company)
	entry = _stock_entry(company, _ensure_warehouse("Rented Out", company), destination, manifest, f"Rental {disposition} return {rental} / {request_id}")
	operation = frappe.get_doc({"doctype": "Rental Inventory Operation", "rental": rental, "operation_type": "return", "request_id": request_id, "stock_entry": entry.name, "disposition": disposition, "items": _operation_items(manifest, disposition)}).insert()
	status = "Returned" if not _has_outstanding_items(rental) else "Partially Returned"
	manifest["doc"].db_set("status", status, update_modified=True)
	return {"operation": operation.name, "stock_entry": entry.name, "status": status, "idempotent": False}


def _has_outstanding_items(rental):
	operations = frappe.get_all("Rental Inventory Operation", filters={"rental": rental}, fields=["name", "operation_type"])
	if not operations:
		return True
	types = {operation.name: operation.operation_type for operation in operations}
	rows = frappe.get_all("Rental Inventory Operation Item", filters={"parent": ("in", list(types))}, fields=["parent", "serial_no", "item_code", "qty"])
	checked_out_serials, returned_serials, quantities = set(), set(), {}
	for row in rows:
		checkout = types[row.parent] == "checkout"
		if row.serial_no:
			if checkout:
				checked_out_serials.add(row.serial_no)
			else:
				returned_serials.add(row.serial_no)
		else:
			quantities[row.item_code] = quantities.get(row.item_code, 0) + (flt(row.qty) if checkout else -flt(row.qty))
	return bool(checked_out_serials - returned_serials or any(qty > 0 for qty in quantities.values()))


def _ensure_warehouse(label: str, company: str) -> str:
	abbr = frappe.get_cached_value("Company", company, "abbr")
	name = f"{label} - {abbr}"
	if not frappe.db.exists("Warehouse", name):
		frappe.get_doc({"doctype": "Warehouse", "warehouse_name": label, "company": company, "is_group": 0}).insert()
	return name
