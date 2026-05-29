import os
import sys
import psycopg2

# Lê a URL de ligação do ambiente ou usa a padrão
db_url = os.getenv(
    "DATABASE_URL", 
    "postgresql://neondb_owner:npg_vGCJmS0u6NqV@ep-patient-hall-apvf70cs.c-7.us-east-1.aws.neon.tech/neondb?sslmode=require"
)

print("A iniciar limpeza de utilizadores na base de dados...")
try:
    conn = psycopg2.connect(db_url)
    cursor = conn.cursor()
    
    # 1. Eliminar favoritos por causa de dependências de Foreign Key
    cursor.execute("DELETE FROM favorites;")
    fav_count = cursor.rowcount
    
    # 2. Eliminar utilizadores
    cursor.execute("DELETE FROM users;")
    user_count = cursor.rowcount
    
    conn.commit()
    print(f"Limpeza concluída com sucesso!")
    print(f"  - {fav_count} favoritos removidos.")
    print(f"  - {user_count} utilizadores eliminados de forma permanente.")
    
    cursor.close()
    conn.close()
except Exception as e:
    print(f"Erro ao limpar utilizadores: {e}")
