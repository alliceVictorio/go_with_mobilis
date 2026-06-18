# 📱 Go with Mobilis - Projeto de Mobilidade Urbana (Leiria)

Este repositório contém o código-fonte completo do projeto **Go with Mobilis**, uma solução digital full-stack desenvolvida para facilitar o acesso à informação sobre transportes públicos da rede **Mobilis** da cidade de Leiria.

O projeto cumpre todos os requisitos definidos no enunciado acadêmico, incluindo a arquitetura cliente-servidor, geolocalização do utilizador, visualização cartográfica, cache local, simulação em tempo real, suporte multi-idioma e notificações.

---

## 🏛️ Arquitetura do Sistema

O sistema segue uma arquitetura cliente-servidor robusta com uma clara separação de responsabilidades (padrão MVC/MVVM no frontend e arquitetura de três camadas no backend).

```mermaid
graph TD
    subgraph Cliente (Mobile)
        F[Ecrãs / UI - Flutter] --> B[Blocs / State Management]
        B --> S[Services - ApiService / LocationService]
        S --> C[Local Cache - Secure Storage / PDF Cache]
    end

    subgraph Servidor (Nuvem / Local)
        S --> |HTTPS / JSON| API[FastAPI - Router & Controllers]
        API --> M[Pydantic Schemas / Database Models]
        M --> DB[(PostgreSQL + PostGIS)]
    end
```

### 1. Frontend (Flutter)
* **View (Ecrãs/Screens):** Interfaces fluidas e centradas no utilizador (`passenger_map_screen.dart`, `login_screen.dart`, `favorites_screen.dart`, etc.).
* **Service/Repository Layer:** Camada isolada para comunicação HTTP assíncrona (`api_service.dart`), gestão de geolocalização (`location_service.dart`) e persistência em cache (`pdf_cache_service.dart`).
* **State Management:** Atualização dinâmica de estado com base em streams de localização GPS e eventos do utilizador.

### 2. Backend (FastAPI + Python)
* **Routes/Endpoints:** Definição clara de rotas REST para autenticação (JWT), paragens, rotas, alertas e favoritos.
* **Database Models (SQLAlchemy):** Representação do esquema da base de dados com suporte geográfico.
* **GTFS Importer:** Scripts automatizados para importar dados oficiais de transportes públicos no formato GTFS (General Transit Feed Specification).

### 3. Base de Dados (PostgreSQL + PostGIS)
* Utilização de extensões espaciais para cálculo preciso de distâncias e localização de paragens próximas em tempo real utilizando queries como `ST_DWithin`.

---

## 💾 Escolhas Tecnológicas e Justificação

| Tecnologia | Função no Projeto | Justificação Técnica e de Design |
| :--- | :--- | :--- |
| **Flutter (Dart)** | Aplicação Móvel | Permite desenvolvimento multiplataforma nativo e de alta performance (60fps), com suporte excelente a mapas e consumo assíncrono de APIs. |
| **FastAPI (Python)** | Servidor / API REST | Extremamente rápido (baseado em Starlette e Pydantic), gera documentação interativa automática (Swagger UI) e suporta programação assíncrona (`async/await`). |
| **PostgreSQL + PostGIS** | Base de Dados | Padrão da indústria para armazenamento relacional e dados geográficos. A extensão PostGIS permite queries espaciais eficientes para geolocalização e proximidade. |
| **flutter_map & Google Maps / CartoDB** | Visualização de Mapas | Integração de mapas com Google Maps (Light Mode) e CartoDB (Dark Mode) para flexibilidade de estilização de rotas e marcadores. |
| **Neon.tech & Render** | Alojamento Cloud | Serviços modernos e gratuitos que permitem colocar a base de dados (Neon) e o backend (Render) online em minutos, facilitando o trabalho colaborativo e a demonstração final. |

---

## ✨ Funcionalidades Implementadas

### 🎯 Funcionalidades Base
1. **Consulta de Linhas, Horários e Percursos:**
   * Visualização dos trajetos completos desenhados no mapa com as respetivas cores oficiais da Mobilis.
   * Consulta interativa da tabela de horários e paragens de cada linha.
   * Integração e visualização de horários oficiais em PDF.
2. **Geolocalização do Utilizador:**
   * Acesso e monitorização dinâmica da localização do utilizador no mapa com botão de recentrar.
3. **Visualização Cartográfica Avançada:**
   * Trajeto pedonal (caminhada da localização do utilizador até à paragem de embarque, e da paragem de desembarque até ao destino) representado no mapa através de **linhas pontilhadas azuis** (`StrokePattern.dashed`).
   * Trajeto de autocarro desenhado com linha contínua na cor da rota correspondente.
4. **Pesquisa Estruturada:**
   * Barra de pesquisa com sugestões automáticas por nome da paragem e listagem inteligente das paragens mais próximas ao local pesquisado.

### 🚀 Funcionalidades Avançadas e Opcionais
1. **Sistema de Favoritos Persistente:**
   * Permite guardar paragens favoritas, sincronizando-as dinamicamente com a conta do utilizador no backend.
2. **Cache Local e Sincronização Inteligente:**
   * **Paragens:** Guardadas em cache persistente no `FlutterSecureStorage`.
   * **Estratégia de Timeout (Cold-Start):** Ao abrir a app pela primeira vez, utiliza um timeout de **40 segundos** para permitir que o servidor gratuito do Render "acorde". Nas consultas seguintes, usa um timeout ultrarrápido de **5 segundos**.
   * **Offline PDFs:** Os horários em PDF descarregados são guardados localmente na pasta de documentos da aplicação para visualização instantânea sem internet.
3. **Notificações Contextuais de Proximidade:**
   * Quando o utilizador inicia uma viagem, a aplicação monitoriza a sua localização e emite alertas pop-up visuais no ecrã à medida que este se aproxima de cada paragem do percurso.
4. **Descoberta Automática de Rede (Auto-Discovery):**
   * Em ambiente de desenvolvimento, a app faz um scan paralelo inteligente à subrede Wi-Fi local para descobrir e conectar-se automaticamente ao backend a correr na máquina do programador (porta 8000), dispensando a configuração manual de IPs.
5. **Suporte Multi-Idioma (i18n):**
   * Tradução completa da aplicação para **Português (PT)** e **Inglês (EN)** com suporte dinâmico a deteção de idioma do sistema.

---

## 🛠️ Como Executar o Projeto

### Requisitos Prévios
* **Flutter SDK** (versão estável mais recente)
* **Python 3.10+**
* Base de dados **PostgreSQL** com extensão **PostGIS** instalada

---

### 🚀 1. Configurar e Iniciar o Backend

1. Aceda à pasta `backend`:
   ```bash
   cd backend
   ```
2. Crie e ative um ambiente virtual:
   ```bash
   python -m venv venv
   # No Windows (PowerShell):
   .\venv\Scripts\Activate.ps1
   # No macOS/Linux:
   source venv/bin/activate
   ```
3. Instale as dependências:
   ```bash
   pip install -r requirements.txt
   ```
4. Configure as variáveis de ambiente no ficheiro `.env` ou utilize a base de dados em nuvem.
5. Execute as migrações e importe os dados do GTFS (opcional):
   ```bash
   python import_all_gtfs.py
   ```
6. Inicie o servidor FastAPI:
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

---

### 📱 2. Configurar e Compilar o Frontend (Mobile)

1. Aceda à pasta do projeto Flutter:
   ```bash
   cd frontend/go_with_mobilis
   ```
2. Obtenha as dependências do Flutter:
   ```bash
   flutter pub get
   ```
3. Execute o analisador para validar o código:
   ```bash
   flutter analyze
   ```
4. Execute a aplicação num emulador ou dispositivo físico:
   ```bash
   flutter run
   ```
5. **Gerar APK para teste em telemóvel Android:**
   ```bash
   flutter build apk --split-per-abi
   ```
   * O ficheiro resultante (`app-arm64-v8a-release.apk`) estará disponível na pasta:
     `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
   * Envie este ficheiro para o seu telemóvel Android e instale-o. Graças ao mecanismo de **Auto-Discovery** e ao backend configurado no **Render**, a app ligará automaticamente!

---

## 📝 Justificação de Escolhas de Design Visual
* **Acessibilidade:** Cores de alto contraste e tipografia de fácil leitura para facilitar a consulta em movimento.
* **Tema Escuro/Claro:** Cores harmoniosas inspiradas na identidade visual da Mobilis de Leiria (azul oficial e verde).
* **Feedback Táctil e Visual:** Transições suaves nos painéis inferiores (sliding bottom sheets), badges dinâmicos para notificações e rotas desenhadas com opacidade equilibrada no mapa.

---

## 👥 Autores e Orientação
* **Projeto:** Go with Mobilis - Unidade Curricular de Projeto de Sistemas de Informação / Desenvolvimento Móvel.
* **Orientação:** Prof.ª Iolanda Bernardino (`iolanda.bernardino@ipleiria.pt`).
