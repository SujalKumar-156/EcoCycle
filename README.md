# EcoCycle

EcoCycle is an e-waste collection and recycling management system built with MySQL and Flask.

## Database relationships

- `Waste_Items` references `Users`, `Categories`, and optionally `Recycling_Batches`.
- `Pickup_Requests` references a waste item and a collection centre. The schema allows one request per item.
- `Pickup_Assignments` references requests and collectors; collectors reference users and collection centres.
- `Inventory` and `Shipments` reference waste items. Shipments also reference collection centres and facilities.
- `Recycling_Batches` reference facilities. `Recovered_Materials` links batches to `Materials`.
- `Users` reference `Roles` and optionally `Organizations`.

The table definitions are in `database/01_schema.sql`; `database/02_collection_inventory.sql` through `database/05_sample_queries.sql` are currently empty. The category and customer-role master data in `06_master_data.sql` is required for registration. Run seed scripts only once and check their fixed IDs against your database first; in particular, `07_operational_sample_data.sql` contains hard-coded IDs and may not match the current auto-increment values.

## Run locally

1. Install Python 3.10 or later and start your local MySQL server.
2. Copy `.env.example` to `.env` and enter your own MySQL username and password. Keep `.env` private.
3. If the `EcoCycle` schema does not already exist, initialize it once using `database/01_schema.sql`. Do not rerun it against an existing schema.
4. Load the required master data if it is not already present.
5. From the project root, run:

   ```powershell
   python -m pip install -r requirements.txt
   python app.py
   ```

6. Open <http://127.0.0.1:5000>.

The server binds to localhost and does not enable debug mode. The frontend remains in the project root; Flask serves the existing HTML, CSS, and JavaScript files.

Run the backend unit tests with:

```powershell
python -m unittest discover -s tests -v
```

These tests stub database responses; configure `.env` and MySQL separately to verify a live connection.

## API

- `GET /api/dashboard`
- `GET /api/categories`
- `GET /api/centres`
- `GET /api/waste-items`
- `POST /api/waste-items` — creates a customer user when user details are provided, then creates the waste item in one transaction. Supplying `user.user_id` uses an existing user instead. It does not create a pickup request.
- `GET /api/pickup-requests`
- `POST /api/pickup-requests` — creates a request for an existing item and centre.
- `GET /api/recycling`

The pickup form calls the waste-item and pickup-request endpoints in sequence. If the second request fails, the UI reports that the waste item was created but the pickup request was not. Inventory and shipment screens remain placeholders because corresponding read endpoints were not requested.

## Database configuration and testing

No database credentials are stored in this repository. The API reports a configuration/database error until `.env` is configured and MySQL is reachable. Database-backed endpoint results cannot be verified without those local credentials and a compatible schema.
