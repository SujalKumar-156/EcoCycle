import os
from contextlib import contextmanager
from pathlib import Path

import mysql.connector
from dotenv import load_dotenv


load_dotenv(Path(__file__).with_name(".env"))


class DatabaseConfigurationError(RuntimeError):
    """Raised when required MySQL environment variables are missing or invalid."""


def get_connection():
    required = ("DB_HOST", "DB_USER", "DB_NAME", "DB_PORT")
    missing = [key for key in required if not os.getenv(key)]
    if missing:
        raise DatabaseConfigurationError(
            "Missing MySQL configuration: "
            + ", ".join(missing)
            + ". Copy .env.example to .env and set your local database values."
        )

    try:
        port = int(os.environ["DB_PORT"])
    except ValueError as exc:
        raise DatabaseConfigurationError("DB_PORT must be a valid port number.") from exc

    if not 1 <= port <= 65535:
        raise DatabaseConfigurationError("DB_PORT must be between 1 and 65535.")

    return mysql.connector.connect(
        host=os.environ["DB_HOST"],
        user=os.environ["DB_USER"],
        password=os.getenv("DB_PASSWORD", ""),
        database=os.environ["DB_NAME"],
        port=port,
        connection_timeout=5,
    )


@contextmanager
def database_cursor():
    connection = get_connection()
    cursor = None
    try:
        cursor = connection.cursor(dictionary=True)
        yield connection, cursor
    except Exception:
        connection.rollback()
        raise
    finally:
        if cursor is not None:
            cursor.close()
        connection.close()
