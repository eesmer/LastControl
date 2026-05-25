#!/usr/bin/env python3

import sys
import json
import sqlite3
import logging
from datetime import datetime

DB_PATH = "/usr/local/lastcontrol/lastcontrol.db"
LOG_PATH = "/var/log/lastcontrol-handler.log"
MAX_PAYLOAD_SIZE = 1024 * 1024  # 1 MB

logging.basicConfig(
    filename=LOG_PATH,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

SYSTEM_INFO_MAP = {
    "system_info_ports": "open_ports",
    "system_info_disk": "disk_usage",
    "system_info_roles": "roles",
    "system_info_ram": "ram_usage",
    "local_users": "local_users",
    "update_report": "update_report",
    "disk_io_load": "disk_io_load",
    "package_inventory": "package_inventory",
}

INVENTORY_FIELDS = [
    "hostname",
    "internal_ip",
    "external_ip",
    "internet_conn",
    "cpu_info",
    "ram_total",
    "disk_list",
    "gpu",
    "wireless",
    "distro",
    "kernel",
    "uptime",
    "last_boot",
    "virt_control",
    "local_date",
    "time_sync",
    "time_zone",
    "bios_vendor",
    "bios_info",
    "bios_version",
    "bios_release_date",
    "bios_revision",
    "bios_firmware_revision",
    "bios_mode",
    "mainboard",
    "product_name",
    "serial_number",
]

def read_payload():
    raw = sys.stdin.buffer.read(MAX_PAYLOAD_SIZE + 1)
    if len(raw) > MAX_PAYLOAD_SIZE:
        logging.error("Payload too large")
        sys.exit(0)
    if not raw:
        sys.exit(0)
    try:
        text = raw.decode("utf-8", errors="replace").strip()
        return json.loads(text)
    except json.JSONDecodeError as e:
        logging.error("Invalid JSON: %s", e)
        sys.exit(0)

def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def clean_value(value):
    if value is None:
        return ""
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False)
    return str(value)

def handle_inventory(data):
    values = [clean_value(data.get(field, "")) for field in INVENTORY_FIELDS]
    hostname = clean_value(data.get("hostname", ""))
    internal_ip = clean_value(data.get("internal_ip", ""))
    distro = clean_value(data.get("distro", ""))
    if not hostname:
        logging.error("Inventory rejected: hostname missing")
        return
    placeholders = ", ".join(["?"] * len(INVENTORY_FIELDS))
    field_list = ", ".join(INVENTORY_FIELDS)
    with get_conn() as conn:
        conn.execute(
            f"""
            INSERT INTO inventory ({field_list})
            VALUES ({placeholders})
            """,
            values
        )
        conn.execute(
            """
            INSERT INTO agents (hostname, ip_address, os_name, last_seen)
            VALUES (?, ?, ?, datetime('now','localtime'))
            ON CONFLICT(hostname) DO UPDATE SET
                ip_address = excluded.ip_address,
                os_name = excluded.os_name,
                last_seen = excluded.last_seen
            """,
            (hostname, internal_ip, distro)
        )
        conn.commit()
    logging.info("Inventory recorded for hostname=%s", hostname)

def handle_system_info(data, info_type):
    hostname = clean_value(data.get("hostname", ""))
    info_data = clean_value(data.get("info_data", ""))
    if not hostname:
        logging.error("System info rejected: hostname missing")
        return
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO system_info (hostname, info_type, info_data)
            VALUES (?, ?, ?)
            """,
            (hostname, info_type, info_data)
        )
        conn.execute(
            """
            UPDATE agents
            SET last_seen = datetime('now','localtime')
            WHERE hostname = ?
            """,
            (hostname,)
        )
        conn.commit()
    logging.info("System info recorded hostname=%s type=%s", hostname, info_type)

def handle_task_check(data):
    hostname = clean_value(data.get("hostname", ""))
    if not hostname:
        logging.error("Task check rejected: hostname missing")
        return
    with get_conn() as conn:
        task = conn.execute(
            """
            SELECT id, task_type, task_payload
            FROM tasks
            WHERE hostname = ?
              AND status = 'pending'
            ORDER BY created_at ASC
            LIMIT 1
            """,
            (hostname,)
        ).fetchone()
        if task is None:
            response = {
                "has_task": False
            }
        else:
            conn.execute(
                """
                UPDATE tasks
                SET status = 'assigned',
                    assigned_at = datetime('now','localtime')
                WHERE id = ?
                """,
                (task["id"],)
            )
            conn.commit()
            response = {
                "has_task": True,
                "task_id": task["id"],
                "task_type": task["task_type"],
                "task_payload": task["task_payload"] or ""
            }
    print(json.dumps(response, ensure_ascii=False))

def handle_task_result(data):
    hostname = clean_value(data.get("hostname", ""))
    try:
       task_id = int(data.get("task_id"))
    except Exception:
       logging.error("Invalid task_id")
       return
    result_status = clean_value(data.get("result_status", "unknown"))
    result_output = clean_value(data.get("result_output", ""))
    if not hostname or not task_id:
        logging.error("Task result rejected: hostname or task_id missing")
        return
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO task_results (
                task_id,
                hostname,
                result_status,
                result_output
            )
            VALUES (?, ?, ?, ?)
            """,
            (task_id, hostname, result_status, result_output)
        )
        conn.execute(
            """
            UPDATE tasks
            SET status = 'completed',
                completed_at = datetime('now','localtime')
            WHERE id = ?
            """,
            (task_id,)
        )
        conn.commit()
    logging.info("Task result recorded hostname=%s task_id=%s", hostname, task_id)

def main():
    data = read_payload()
    origin = clean_value(data.get("origin", ""))
    if not origin:
        logging.error("Origin missing")
        return
    if origin == "inventory":
        handle_inventory(data)
    elif origin in SYSTEM_INFO_MAP:
        handle_system_info(data, SYSTEM_INFO_MAP[origin])
    elif origin == "task_check":
        handle_task_check(data)
    elif origin == "task_result":
        handle_task_result(data)
    else:
        logging.error("Unknown origin: %s", origin)
if __name__ == "__main__":
    main()
