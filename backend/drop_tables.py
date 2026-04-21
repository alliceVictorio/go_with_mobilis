import database
import models

print("A dropar todas as tabelas (isto não apaga a base de dados, apenas as tabelas)...")
models.Base.metadata.drop_all(bind=database.engine)
print("Todas as tabelas foram apagadas. Se reiniciares o backend, elas serão recriadas limpas.")
