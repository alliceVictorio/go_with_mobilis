from sqlalchemy import create_engine, text
engine = create_engine('postgresql://postgres:1234@localhost:5432/go_with_mobilis')
with engine.connect() as conn:
    res = conn.execute(text('SELECT email, is_admin FROM users')).fetchall()
    print('Users:', res)
