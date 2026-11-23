import unittest
from contextlib import contextmanager
from datetime import date, datetime, timedelta
from decimal import Decimal
from unittest.mock import Mock, patch

from app import app


class FakeConnection:
    def __init__(self):
        self.commits = 0
        self.rollbacks = 0
        self.closed = False

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1

    def close(self):
        self.closed = True


class FakeCursor:
    def __init__(self):
        self.one = None
        self.many = []
        self.lastrowid = None
        self.executed = []
        self.closed = False

    def execute(self, query, params=None):
        normalized = " ".join(query.split())
        self.executed.append((normalized, params))
        self.one = None
        self.many = []

        if "FROM Categories WHERE category_id = %s" in normalized:
            self.one = {"category_id": 3}
        elif "FROM Roles WHERE UPPER(role_name)" in normalized:
            self.one = {"role_id": 2}
        elif "FROM Waste_Items WHERE item_id = %s" in normalized:
            self.one = {"item_id": 25}
        elif "FROM Collection_Centres WHERE centre_id = %s" in normalized:
            self.one = {"centre_id": 2}
        elif "FROM Pickup_Requests WHERE item_id = %s" in normalized:
            self.one = None
        elif normalized.startswith("INSERT INTO Users"):
            self.lastrowid = 41
        elif normalized.startswith("INSERT INTO Waste_Items"):
            self.lastrowid = 84
        elif normalized.startswith("INSERT INTO Pickup_Requests"):
            self.lastrowid = 96

    def fetchone(self):
        return self.one

    def fetchall(self):
        return self.many

    def close(self):
        self.closed = True


@contextmanager
def fake_database(connection, cursor):
    try:
        yield connection, cursor
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()
        connection.close()


class EcoCycleApiTests(unittest.TestCase):
    def setUp(self):
        app.config.update(TESTING=True)
        self.client = app.test_client()

    def get_with_database_rows(self, path, one=None, many=None):
        connection = FakeConnection()
        cursor = Mock()
        cursor.fetchone.return_value = one
        cursor.fetchall.return_value = many or []
        with patch("app.database_cursor", return_value=fake_database(connection, cursor)):
            response = self.client.get(path)
        self.assertEqual(response.status_code, 200)
        self.assertTrue(cursor.closed)
        self.assertTrue(connection.closed)
        return response.get_json()

    def test_read_endpoints_serialize_database_records(self):
        dashboard = self.get_with_database_rows(
            "/api/dashboard",
            one={
                "total_registered_items": 6,
                "pending_pickup_requests": 2,
                "total_shipments": 6,
                "completed_recycling_batches": 2,
                "total_recovered_material_kg": Decimal("3.80"),
            },
        )
        self.assertEqual(dashboard["total_registered_items"], 6)
        self.assertEqual(dashboard["total_recovered_material_kg"], 3.8)

        categories = self.get_with_database_rows(
            "/api/categories",
            many=[{"category_id": 3, "category_name": "Computers", "description": None}],
        )
        self.assertEqual(categories["categories"][0]["category_name"], "Computers")

        centres = self.get_with_database_rows(
            "/api/centres",
            many=[{"centre_id": 2, "centre_name": "Bihta Collection Hub", "city": "Bihta", "address": None}],
        )
        self.assertEqual(centres["centres"][0]["centre_id"], 2)

        items = self.get_with_database_rows(
            "/api/waste-items",
            many=[{
                "item_id": 84,
                "item_name": "Laptop",
                "category_name": "Computers",
                "user_name": "Asha Kumar",
                "weight_kg": Decimal("2.50"),
                "registered_at": datetime(2026, 11, 23, 12, 0),
            }],
        )
        self.assertEqual(items["items"][0]["weight_kg"], 2.5)
        self.assertNotIn("password_hash", items["items"][0])

        requests = self.get_with_database_rows(
            "/api/pickup-requests",
            many=[{
                "request_id": 96,
                "item_name": "Laptop",
                "user_name": "Asha Kumar",
                "centre_name": "Bihta Collection Hub",
                "requested_date": date(2026, 11, 24),
            }],
        )
        self.assertEqual(requests["pickup_requests"][0]["requested_date"], "2026-11-24")

        batches = self.get_with_database_rows(
            "/api/recycling",
            many=[
                {
                    "batch_id": 5,
                    "batch_code": "ECO-BATCH-005",
                    "processed_at": None,
                    "status": "COMPLETED",
                    "facility_name": "Tech Recovery Unit",
                    "facility_city": "Bihta",
                    "recovery_id": 8,
                    "recovered_weight_kg": Decimal("1.20"),
                    "material_name": "Copper",
                    "unit": "kg",
                },
                {
                    "batch_id": 5,
                    "batch_code": "ECO-BATCH-005",
                    "processed_at": None,
                    "status": "COMPLETED",
                    "facility_name": "Tech Recovery Unit",
                    "facility_city": "Bihta",
                    "recovery_id": 9,
                    "recovered_weight_kg": Decimal("0.50"),
                    "material_name": "Plastic",
                    "unit": "kg",
                },
            ],
        )
        self.assertEqual(len(batches["batches"]), 1)
        self.assertEqual(len(batches["batches"][0]["recovered_materials"]), 2)

    def test_create_waste_item_creates_customer_and_item_atomically(self):
        connection = FakeConnection()
        cursor = FakeCursor()
        with patch("app.database_cursor", return_value=fake_database(connection, cursor)) as db:
            response = self.client.post(
                "/api/waste-items",
                json={
                    "item_name": "Laptop",
                    "category_id": 3,
                    "brand": "Dell",
                    "item_condition": "Damaged",
                    "weight_kg": 2.5,
                    "user": {
                        "full_name": "Asha Kumar",
                        "email": "asha@example.com",
                        "phone": "9000000000",
                    },
                },
            )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.get_json()["item_id"], 84)
        self.assertEqual(connection.commits, 1)
        self.assertTrue(cursor.closed)
        self.assertTrue(connection.closed)
        self.assertFalse(any(query.startswith("INSERT INTO Pickup_Requests") for query, _ in cursor.executed))
        user_insert = next(params for query, params in cursor.executed if query.startswith("INSERT INTO Users"))
        item_insert = next(params for query, params in cursor.executed if query.startswith("INSERT INTO Waste_Items"))
        self.assertEqual(user_insert, (2, "Asha Kumar", "asha@example.com", "9000000000"))
        self.assertEqual(item_insert, (41, 3, "Laptop", "Dell", "Damaged", Decimal("2.5")))

    def test_invalid_waste_item_is_rejected_before_database_access(self):
        with patch("app.database_cursor") as db:
            response = self.client.post(
                "/api/waste-items",
                json={
                    "item_name": "Laptop",
                    "category_id": 3,
                    "weight_kg": -1,
                    "user": {"full_name": "Asha Kumar", "email": "asha@example.com"},
                },
            )

        self.assertEqual(response.status_code, 400)
        self.assertIn("greater than zero", response.get_json()["error"])
        db.assert_not_called()

    def test_create_pickup_request_uses_existing_item_and_centre(self):
        connection = FakeConnection()
        cursor = FakeCursor()
        requested_date = (date.today() + timedelta(days=1)).isoformat()
        with patch("app.database_cursor", return_value=fake_database(connection, cursor)):
            response = self.client.post(
                "/api/pickup-requests",
                json={
                    "item_id": 25,
                    "centre_id": 2,
                    "requested_date": requested_date,
                    "preferred_slot": "10 AM - 12 PM",
                },
            )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.get_json()["request_id"], 96)
        self.assertEqual(connection.commits, 1)
        insert = next(params for query, params in cursor.executed if query.startswith("INSERT INTO Pickup_Requests"))
        self.assertEqual(insert, (25, 2, date.fromisoformat(requested_date), "10 AM - 12 PM"))

    def test_pickup_request_rejects_a_past_date(self):
        with patch("app.database_cursor") as db:
            response = self.client.post(
                "/api/pickup-requests",
                json={
                    "item_id": 25,
                    "centre_id": 2,
                    "requested_date": (date.today() - timedelta(days=1)).isoformat(),
                },
            )

        self.assertEqual(response.status_code, 400)
        self.assertIn("cannot be in the past", response.get_json()["error"])
        db.assert_not_called()


if __name__ == "__main__":
    unittest.main()
