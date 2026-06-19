from sqlalchemy import text
from database import engine
with engine.connect() as conn:
    res = conn.execute(text('SELECT email, is_admin FROM users')).fetchall()
    print('Users:', res)
