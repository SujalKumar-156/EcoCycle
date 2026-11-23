import logging
import re
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

import mysql.connector
from flask import Flask, current_app, jsonify, request, send_file
from mysql.connector import IntegrityError
from werkzeug.exceptions import HTTPException

from db import DatabaseConfigurationError, database_cursor


ROOT = Path(__file__).resolve().parent
app = Flask(__name__, static_folder=None)
app.config["JSON_SORT_KEYS"] = False


class InputValidationError(ValueError):
    pass


def api_error(message, status):
    return jsonify({"error": message}), status


def json_safe(value):
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    if isinstance(value, dict):
        return {key: json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [json_safe(item) for item in value]
    return value


def json_object():
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        raise InputValidationError("Request body must be a JSON object.")
    return body


def required_text(data, field, label, maximum):
    value = data.get(field)
    if not isinstance(value, str) or not value.strip():
        raise InputValidationError(f"{label} is required.")
    value = value.strip()
    if len(value) > maximum:
        raise InputValidationError(f"{label} must be {maximum} characters or fewer.")
    return value


def optional_text(data, field, label, maximum):
    value = data.get(field)
    if value is None or value == "":
        return None
    if not isinstance(value, str):
        raise InputValidationError(f"{label} must be text.")
    value = value.strip()
    if not value:
        return None
    if len(value) > maximum:
        raise InputValidationError(f"{label} must be {maximum} characters or fewer.")
    return value


def positive_id(value, label):
    if isinstance(value, bool):
        raise InputValidationError(f"{label} must be a positive integer.")
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        raise InputValidationError(f"{label} must be a positive integer.") from None
    if parsed <= 0 or str(parsed) != str(value).strip():
        raise InputValidationError(f"{label} must be a positive integer.")
    return parsed


def positive_weight(value):
    if isinstance(value, bool) or value is None:
        raise InputValidationError("Weight must be greater than zero.")
    try:
        weight = Decimal(str(value))
    except (InvalidOperation, ValueError):
        raise InputValidationError("Weight must be a valid number.") from None
    if not weight.is_finite() or weight <= 0:
        raise InputValidationError("Weight must be greater than zero.")
    if weight > Decimal("99999999.99") or weight.as_tuple().exponent < -2:
        raise InputValidationError("Weight must fit the database precision (up to 2 decimal places).")
    return weight


def valid_email(value):
    if len(value) > 100 or not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", value):
        raise InputValidationError("Enter a valid email address (maximum 100 characters).")
    return value


def valid_phone(value):
    if value and not re.fullmatch(r"[0-9+() .-]{1,15}", value):
        raise InputValidationError("Phone number may contain digits, spaces, +, parentheses, dots, and hyphens.")
    return value


def valid_request_date(value):
    try:
        parsed = date.fromisoformat(value)
    except (TypeError, ValueError):
        raise InputValidationError("Preferred date must use YYYY-MM-DD format.") from None
    if parsed < date.today():
        raise InputValidationError("Preferred date cannot be in the past.")
    return parsed


@app.get("/")
def home():
    return send_file(ROOT / "index.html")


@app.get("/styles.css")
def styles():
    return send_file(ROOT / "styles.css", mimetype="text/css")


@app.get("/app.js")
def frontend_script():
    return send_file(ROOT / "app.js", mimetype="text/javascript")


@app.get("/api/dashboard")
def dashboard():
    query = """
        SELECT
            (SELECT COUNT(*) FROM Waste_Items) AS total_registered_items,
            (SELECT COUNT(*) FROM Pickup_Requests
             WHERE UPPER(status) = 'PENDING') AS pending_pickup_requests,
            (SELECT COUNT(*) FROM Shipments) AS total_shipments,
            (SELECT COUNT(*) FROM Recycling_Batches
             WHERE UPPER(status) = 'COMPLETED') AS completed_recycling_batches,
            COALESCE(
                (SELECT SUM(recovered_weight_kg) FROM Recovered_Materials),
                0
            ) AS total_recovered_material_kg
    """
    with database_cursor() as (_, cursor):
        cursor.execute(query)
        result = cursor.fetchone()
    return jsonify(json_safe(result))


@app.get("/api/categories")
def categories():
    with database_cursor() as (_, cursor):
        cursor.execute(
            "SELECT category_id, category_name, description "
            "FROM Categories ORDER BY category_name"
        )
        rows = cursor.fetchall()
    return jsonify({"categories": json_safe(rows)})


@app.get("/api/centres")
def centres():
    with database_cursor() as (_, cursor):
        cursor.execute(
            "SELECT centre_id, centre_name, city, address "
            "FROM Collection_Centres ORDER BY city, centre_name"
        )
        rows = cursor.fetchall()
    return jsonify({"centres": json_safe(rows)})


@app.get("/api/waste-items")
def get_waste_items():
    query = """
        SELECT wi.item_id, wi.item_name, wi.brand, wi.item_condition,
               wi.weight_kg, wi.status, wi.registered_at, wi.batch_id,
               c.category_id, c.category_name,
               u.user_id, u.full_name AS user_name, u.email AS user_email
        FROM Waste_Items AS wi
        JOIN Categories AS c ON c.category_id = wi.category_id
        JOIN Users AS u ON u.user_id = wi.user_id
        ORDER BY wi.registered_at DESC, wi.item_id DESC
    """
    with database_cursor() as (_, cursor):
        cursor.execute(query)
        rows = cursor.fetchall()
    return jsonify({"items": json_safe(rows)})


@app.post("/api/waste-items")
def create_waste_item():
    try:
        body = json_object()
        item_name = required_text(body, "item_name", "Item name", 150)
        category_id = positive_id(body.get("category_id"), "Category")
        brand = optional_text(body, "brand", "Brand", 100)
        item_condition = optional_text(body, "item_condition", "Condition", 50)
        weight = positive_weight(body.get("weight_kg"))
        user = body.get("user")
        if not isinstance(user, dict):
            raise InputValidationError("User information is required.")

        user_id_value = user.get("user_id")
        if user_id_value is not None:
            user_id = positive_id(user_id_value, "User ID")
            full_name = email = phone = None
        else:
            full_name = required_text(user, "full_name", "Full name", 100)
            email = valid_email(required_text(user, "email", "Email", 100))
            phone = valid_phone(optional_text(user, "phone", "Phone", 15))
            user_id = None
    except InputValidationError as exc:
        return api_error(str(exc), 400)

    try:
        with database_cursor() as (connection, cursor):
            cursor.execute(
                "SELECT category_id FROM Categories WHERE category_id = %s",
                (category_id,),
            )
            if cursor.fetchone() is None:
                return api_error("The selected category does not exist.", 404)

            if user_id is not None:
                cursor.execute("SELECT user_id FROM Users WHERE user_id = %s", (user_id,))
                if cursor.fetchone() is None:
                    return api_error("The selected user does not exist.", 404)
            else:
                cursor.execute(
                    "SELECT role_id FROM Roles WHERE UPPER(role_name) = 'CUSTOMER' LIMIT 1"
                )
                role = cursor.fetchone()
                if role is None:
                    return api_error(
                        "The CUSTOMER role is missing. Load the project's master data first.",
                        409,
                    )
                cursor.execute(
                    "INSERT INTO Users (role_id, full_name, email, phone) "
                    "VALUES (%s, %s, %s, %s)",
                    (role["role_id"], full_name, email, phone),
                )
                user_id = cursor.lastrowid

            cursor.execute(
                """
                INSERT INTO Waste_Items
                    (user_id, category_id, item_name, brand, item_condition, weight_kg)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (user_id, category_id, item_name, brand, item_condition, weight),
            )
            item_id = cursor.lastrowid
            connection.commit()
    except IntegrityError as exc:
        if exc.errno == 1062:
            return api_error("That email address is already registered. Use the existing user's ID.", 409)
        if exc.errno == 1452:
            return api_error("A related user or category record no longer exists.", 409)
        raise

    return jsonify({"message": "Waste item registered.", "item_id": item_id}), 201


@app.get("/api/pickup-requests")
def get_pickup_requests():
    query = """
        SELECT pr.request_id, pr.item_id, pr.centre_id, pr.requested_date,
               pr.preferred_slot, pr.status, pr.created_at,
               wi.item_name, wi.brand, wi.item_condition, wi.weight_kg,
               c.category_name, u.user_id, u.full_name AS user_name,
               u.email AS user_email, cc.centre_name, cc.city
        FROM Pickup_Requests AS pr
        JOIN Waste_Items AS wi ON wi.item_id = pr.item_id
        JOIN Categories AS c ON c.category_id = wi.category_id
        JOIN Users AS u ON u.user_id = wi.user_id
        JOIN Collection_Centres AS cc ON cc.centre_id = pr.centre_id
        ORDER BY pr.requested_date DESC, pr.request_id DESC
    """
    with database_cursor() as (_, cursor):
        cursor.execute(query)
        rows = cursor.fetchall()
    return jsonify({"pickup_requests": json_safe(rows)})


@app.post("/api/pickup-requests")
def create_pickup_request():
    try:
        body = json_object()
        item_id = positive_id(body.get("item_id"), "Item ID")
        centre_id = positive_id(body.get("centre_id"), "Collection centre")
        requested_date = valid_request_date(
            required_text(body, "requested_date", "Preferred date", 10)
        )
        preferred_slot = optional_text(body, "preferred_slot", "Preferred time slot", 50)
    except InputValidationError as exc:
        return api_error(str(exc), 400)

    try:
        with database_cursor() as (connection, cursor):
            cursor.execute("SELECT item_id FROM Waste_Items WHERE item_id = %s", (item_id,))
            if cursor.fetchone() is None:
                return api_error("The selected waste item does not exist.", 404)

            cursor.execute(
                "SELECT centre_id FROM Collection_Centres WHERE centre_id = %s",
                (centre_id,),
            )
            if cursor.fetchone() is None:
                return api_error("The selected collection centre does not exist.", 404)

            cursor.execute(
                "SELECT request_id FROM Pickup_Requests WHERE item_id = %s",
                (item_id,),
            )
            if cursor.fetchone() is not None:
                return api_error("A pickup request already exists for this waste item.", 409)

            cursor.execute(
                """
                INSERT INTO Pickup_Requests
                    (item_id, centre_id, requested_date, preferred_slot)
                VALUES (%s, %s, %s, %s)
                """,
                (item_id, centre_id, requested_date, preferred_slot),
            )
            request_id = cursor.lastrowid
            connection.commit()
    except IntegrityError as exc:
        if exc.errno == 1062:
            return api_error("A pickup request already exists for this waste item.", 409)
        if exc.errno == 1452:
            return api_error("The selected waste item or collection centre no longer exists.", 409)
        raise

    return jsonify({"message": "Pickup request created.", "request_id": request_id}), 201


@app.get("/api/recycling")
def recycling():
    query = """
        SELECT rb.batch_id, rb.batch_code, rb.processed_at, rb.status,
               f.facility_name, f.city AS facility_city,
               rm.recovery_id, rm.recovered_weight_kg,
               m.material_name, m.unit
        FROM Recycling_Batches AS rb
        JOIN Facilities AS f ON f.facility_id = rb.facility_id
        LEFT JOIN Recovered_Materials AS rm ON rm.batch_id = rb.batch_id
        LEFT JOIN Materials AS m ON m.material_id = rm.material_id
        ORDER BY rb.batch_id DESC, rm.recovery_id
    """
    with database_cursor() as (_, cursor):
        cursor.execute(query)
        rows = cursor.fetchall()

    batches = {}
    for row in rows:
        batch_id = row["batch_id"]
        if batch_id not in batches:
            batches[batch_id] = {
                "batch_id": batch_id,
                "batch_code": row["batch_code"],
                "processed_at": row["processed_at"],
                "status": row["status"],
                "facility_name": row["facility_name"],
                "facility_city": row["facility_city"],
                "recovered_materials": [],
            }
        if row["recovery_id"] is not None:
            batches[batch_id]["recovered_materials"].append(
                {
                    "recovery_id": row["recovery_id"],
                    "material_name": row["material_name"],
                    "recovered_weight_kg": row["recovered_weight_kg"],
                    "unit": row["unit"],
                }
            )
    return jsonify({"batches": json_safe(list(batches.values()))})


@app.errorhandler(DatabaseConfigurationError)
def handle_database_configuration_error(error):
    current_app.logger.error("%s", error)
    return api_error(str(error), 503)

@app.errorhandler(mysql.connector.Error)
def handle_database_error(error):
    current_app.logger.exception("MySQL operation failed")
    return jsonify({
        "error": str(error),
        "mysql_error_code": error.errno
    }), 503
# @app.errorhandler(mysql.connector.Error)
# def handle_database_error(error):
#     current_app.logger.exception("MySQL operation failed")
#     return api_error("Database operation failed. Check the local MySQL service and schema.", 503)


@app.errorhandler(HTTPException)
def handle_http_error(error):
    if request.path.startswith("/api/"):
        return api_error(error.description, error.code or 500)
    return error


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    app.run(host="127.0.0.1", port=5000, debug=False)
