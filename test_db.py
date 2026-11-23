
from db import get_connection

try:
    connection = get_connection()
    print("MySQL connection successful!")

    cursor = connection.cursor()
    cursor.execute("SELECT DATABASE()")
    print("Connected database:", cursor.fetchone()[0])

    cursor.close()
    connection.close()

except Exception as e:
    print("MySQL connection failed:")
    print(type(e).__name__, ":", e)
