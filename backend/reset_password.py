import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine, text
from auth import pwd_context

engine = create_engine('postgresql://postgres:1234@localhost:5432/go_with_mobilis')
new_password = "123456"
hashed_password = pwd_context.hash(new_password)

with engine.connect() as conn:
    conn.execute(text("UPDATE users SET hashed_password = :hash WHERE email = 'admin@mobilis.pt'"), {"hash": hashed_password})
    conn.commit()

print("Password reset successfully for admin@mobilis.pt to: 123456")
