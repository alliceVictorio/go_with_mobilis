# Guia Completo: Implementação do Cenário C (Backend e Base de Dados na Nuvem)

Este guia prático e detalhado explica como tu e o teu colega podem colocar o backend e a base de dados do **"Go with Mobilis"** online e partilhados na nuvem em menos de 10 minutos.

---

## 🛠️ Passo 1: Criar a Base de Dados PostgreSQL + PostGIS (Grátis)

Utilizaremos o **Neon.tech**, que é um serviço excelente e gratuito que cria bases de dados PostgreSQL em segundos na nuvem.

1. Acedam ao site **[https://neon.tech/](https://neon.tech/)** e criem uma conta.
2. Criem um novo projeto com o nome `go_with_mobilis`.
3. Escolham a região mais próxima (ex: **Frankfurt / Europe** para menor latência em Portugal).
4. No Dashboard do Neon, copiem a vossa **Connection String** (ConnectionString) que se parece com isto:
   ```text
   postgresql://alex:password@ep-cool-waterfall-123456.eu-central-1.aws.neon.tech/neondb?sslmode=require
   ```
5. Acedam ao separador **SQL Editor** do Neon ou liguem-se através do pgAdmin e ativem a extensão geográfica **PostGIS** com a seguinte query:
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   ```

---

## 🚀 Passo 2: Publicar o Backend no Render (Grátis)

O **Render** é o serviço ideal para colocar o servidor Python/FastAPI online.

1. Acedam a **[https://render.com/](https://render.com/)** e criem conta (podem fazer login direto com o GitHub).
2. Criem um novo **Web Service**.
3. Liguem o vosso repositório de GitHub onde têm o projeto "Go with Mobilis".
4. Configurem os seguintes parâmetros na criação do serviço:
   * **Name**: `go-with-mobilis-backend`
   * **Root Directory**: `backend` (importante, para o Render saber que a API está nesta subpasta)
   * **Environment**: `Python 3`
   * **Build Command**: `pip install -r requirements.txt`
   * **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
5. No mesmo ecrã, cliquem em **Advanced** -> **Add Environment Variable** e criem a seguinte variável:
   * **Key**: `DATABASE_URL`
   * **Value**: *Colem aqui a Connection String que copiaram do Neon no Passo 1.* (Nota: Certifiquem-se de que termina com `?sslmode=require` para garantir a ligação encriptada exigida pelo Neon).
6. Cliquem em **Create Web Service**. 

*O Render vai compilar e inicializar o vosso backend. Em 2-3 minutos, ele dará um link público (ex: `https://go-with-mobilis-backend.onrender.com`).*

---

## 📱 Passo 3: Configurar a App Flutter para o Backend na Nuvem

Agora que a API está online, tu e o teu colega só precisam de configurar as vossas apps móveis para se ligarem a esse novo link!

1. Na pasta da vossa app Flutter, abram o ficheiro **`lib/services/api_service.dart`** (ou onde definem o endereço do backend).
2. Substituam o endereço IP local pelo endereço público gerado pelo Render:
   ```dart
   // Em api_service.dart:
   static const String baseUrl = "https://go-with-mobilis-backend.onrender.com";
   ```
3. Compilem a aplicação Flutter nos vossos respetivos telemóveis ou emuladores.

---

## 🎉 O que ganham com isto?
* **Base de Dados Única**: Todos os utilizadores criados por ti ou pelo teu colega estarão guardados na nuvem do Neon.
* **Autenticação Partilhada**: Podem iniciar sessão com os mesmos utilizadores em telemóveis físicos diferentes ao mesmo tempo.
* **Favoritos em Tempo Real**: Se adicionares uma paragem aos favoritos no teu telemóvel, ela aparecerá na tua conta mesmo se iniciares sessão a partir do telemóvel do teu colega.
* **Apresentação Perfeita**: No dia da apresentação do projeto final ao júri/professores, o sistema estará 100% online e a funcionar, sem necessidade de terem servidores locais a correr nos vossos portáteis na sala de aulas!
