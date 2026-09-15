"""Idempotent first-run setup for the client Docker deployment."""

from __future__ import annotations

import os
from pathlib import Path

import frappe

from lightbenders_warehouse.setup.import_inventory_json import import_file
from lightbenders_warehouse.services.rental_availability import get_rental_warehouse


def bootstrap_initial_inventory() -> dict:
	company = os.environ.get("COMPANY_NAME", "Lightblenders")
	abbr = os.environ.get("COMPANY_ABBR", "LB")
	currency = os.environ.get("COMPANY_CURRENCY", "NPR")
	country = os.environ.get("COMPANY_COUNTRY", "Nepal")
	_ensure_transit_warehouse_type()
	_ensure_stock_uom()
	_ensure_material_receipt_type()
	frappe.db.set_single_value("Stock Settings", "use_serial_batch_fields", 1)
	frappe.db.set_single_value("Stock Settings", "enable_serial_and_batch_no_for_item", 1)
	_ensure_company(company, abbr, currency, country)
	frappe.db.set_single_value("Global Defaults", "default_company", company)
	_ensure_rental_warehouse(company)
	result = import_file(str(_initial_inventory_file()))
	frappe.db.commit()
	return {"company": company, "warehouse": get_rental_warehouse(company), **result}


def _ensure_company(company: str, abbr: str, currency: str, country: str) -> None:
	if frappe.db.exists("Company", company):
		existing_abbr = frappe.get_cached_value("Company", company, "abbr")
		if existing_abbr != abbr:
			frappe.throw(f"Company {company} already exists with abbreviation {existing_abbr}, not {abbr}.")
		return
	frappe.get_doc(
		{
			"doctype": "Company",
			"company_name": company,
			"abbr": abbr,
			"default_currency": currency,
			"country": country,
		}
	).insert(ignore_permissions=True)


def _ensure_transit_warehouse_type() -> None:
	if not frappe.db.exists("Warehouse Type", "Transit"):
		frappe.get_doc({"doctype": "Warehouse Type", "name": "Transit"}).insert(ignore_permissions=True)


def _ensure_stock_uom() -> None:
	if not frappe.db.exists("UOM", "Nos"):
		frappe.get_doc({"doctype": "UOM", "uom_name": "Nos"}).insert(ignore_permissions=True)


def _ensure_material_receipt_type() -> None:
	if not frappe.db.exists("Stock Entry Type", "Material Receipt"):
		frappe.get_doc(
			{"doctype": "Stock Entry Type", "name": "Material Receipt", "purpose": "Material Receipt"}
		).insert(ignore_permissions=True)


def _ensure_rental_warehouse(company: str) -> None:
	abbr = frappe.get_cached_value("Company", company, "abbr")
	warehouse = f"Main Store Floor - {abbr}"
	if frappe.db.exists("Warehouse", warehouse):
		return
	frappe.get_doc(
		{
			"doctype": "Warehouse",
			"warehouse_name": "Main Store Floor",
			"company": company,
			"is_group": 0,
		}
	).insert(ignore_permissions=True)


def _initial_inventory_file() -> Path:
	return Path(__file__).with_name("data") / "initial_inventory.json"
