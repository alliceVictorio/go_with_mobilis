from database import engine
import pandas as pd
df = pd.read_sql("SELECT id, ST_AsText(geom) as point FROM stops WHERE id='S2_03'", engine)
print(df)
