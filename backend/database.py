from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Configuração da URL de ligação ao PostgreSQL [cite: 159, 198]
# postgresql://utilizador:password@servidor:porta/nome_da_base_de_dados
SQLALCHEMY_DATABASE_URL = "postgresql://postgres:1234@localhost:5432/go_with_mobilis"

# O Engine é o componente que gere a ligação física à BD [cite: 105]
engine = create_engine(SQLALCHEMY_DATABASE_URL)

# SessionLocal será a fábrica de sessões para as nossas rotas da API [cite: 19]
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base será a classe pai de todos os nossos modelos (tabelas) [cite: 57]
Base = declarative_base()

# Dependência para obter a sessão da BD em cada pedido da API [cite: 20]
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()