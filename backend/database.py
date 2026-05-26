import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Configuração da URL de ligação ao PostgreSQL
# Carrega dinamicamente das variáveis de ambiente para produção na nuvem (Render/Railway)
# com fallback para o ambiente local do PostgreSQL
SQLALCHEMY_DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "postgresql://postgres:1234@localhost:5432/go_with_mobilis"
)

# Render/Heroku por vezes usam o prefixo 'postgres://' que o SQLAlchemy >= 1.4 desaprova
if SQLALCHEMY_DATABASE_URL.startswith("postgres://"):
    SQLALCHEMY_DATABASE_URL = SQLALCHEMY_DATABASE_URL.replace("postgres://", "postgresql://", 1)

# O Engine é o componente que gere a ligação física à BD
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True
)

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