# Go with Mobilis - Relatório de Projeto Corrigido

**Licenciatura em Engenharia Informática**  
**Autores**: Allice Victorio, Tiago Matias  
**Orientadora**: Professora Doutora Iolanda Bernardino  
*Leiria, julho de 2026*

---

## Resumo

O presente trabalho descreve o desenvolvimento e implementação do **Go with Mobilis**, uma solução tecnológica integrada desenhada para modernizar o acesso à informação e otimizar a experiência de utilização da rede de transportes urbanos Mobilis na cidade de Leiria. O projeto responde a limitações tradicionais sentidas pelos passageiros, como a consulta complexa de horários estáticos e a ausência de alertas de serviço em tempo real.

O objetivo principal consistiu na criação de um ecossistema digital composto por três componentes: uma aplicação móvel para o passageiro (Flutter/Dart com padrão BLoC), uma API backend segura (Python/FastAPI) e uma base de dados geoespacial na nuvem (PostgreSQL/PostGIS), estruturada segundo o padrão internacional GTFS (General Transit Feed Specification).

A nível de funcionalidades, a aplicação oferece visualização de rotas com mapas híbridos (Google Maps no modo claro e CartoDB no modo escuro), cálculo geográfico de paragens próximas via GPS, estimativa de tempos de chegada, favoritos sincronizados na nuvem e acesso offline a horários PDF através de um sistema de cache local. Disponibiliza ainda um painel móvel administrativo para monitorização de estatísticas, publicação e gestão de alertas de trânsito, e controlo simplificado do estado de linhas e utilizadores.

A solução foi alojada com sucesso em produção através de plataformas SaaS de deployment contínuo (Render para a API, Neon para a base de dados serverless, Brevo para e-mails transacionais e Netlify para serviços web secundários).

Como conclusão, o projeto atingiu a totalidade dos objetivos com elevado rigor técnico. A arquitetura demonstrou ser altamente segura — protegendo dados com tokens JWT e cofres criptográficos de hardware (Secure Storage) — e resiliente nos cálculos geográficos. O sistema encontra-se 100% online e operacional, comprovando a viabilidade de conceber uma plataforma profissional, sustentável e gratuita para a mobilidade inteligente de Leiria.

**Palavras-chave**: Mobilidade Urbana, GTFS, PostGIS, FastAPI, Flutter, SaaS, Sistemas de Informação Geográfica (SIG).

---

## Abstract

This paper describes the planning, development, and implementation of **Go with Mobilis**, an integrated and intelligent technological ecosystem designed to modernize information access and optimize the user experience within the Mobilis urban transit network in the city of Leiria, Portugal. The project emerged as a response to traditional daily challenges faced by passengers, such as complex paper-based timetable consultations, the absence of intuitive geographical navigation tools, and the lack of centralized, real-time transit alerts.

The primary objective of this work was to develop a cross-platform, high-performance digital ecosystem consisting of three core components: a passenger mobile application (developed in Flutter/Dart utilizing reactive state management via the BLoC pattern), a robust and secure backend Application Programming Interface (API) built with Python/FastAPI, and a cloud-hosted relational geospatial database (PostgreSQL with the PostGIS spatial extension) strictly modeled in compliance with the GTFS (General Transit Feed Specification) international transit data standard.

Regarding the implemented functionalities, the mobile client offers interactive maps powered by Google Maps (in Light Mode) and CartoDB (in Dark Mode) tile servers, user geolocalization to instantly calculate nearby stops within walking distance, estimated upcoming bus arrival timetables, a cloud-synchronized favorites system for routes and stops, and a resilient offline mode through local cache storage of official PDF transit guides. In addition to the passenger experience, the application features an advanced mobile administrative dashboard that enables the transit operator to monitor system statistics, publish instant traffic alerts, toggle route activity states, and manage user admin privileges directly from their smartphones.

The infrastructure of the final solution was successfully deployed to production using modern SaaS cloud platforms (Render for the API, Neon for the serverless database, Brevo for high-deliverability transactional email processing, and Netlify for secondary static web assets), establishing an automated continuous integration and continuous deployment (CI/CD) pipeline linked with a GitHub repository.

In conclusion, the project successfully achieved all proposed objectives with software engineering excellence. The deployed architecture proved to be highly secure — protecting user session credentials via server-side signed JWTs and client-side hardware-level encryption (Secure Storage) — and highly resilient in processing geographical and chronological data. The final system is 100% online and fully operational for continuous use, demonstrating the feasibility of designing a professional, sustainable, free, and privacy-focused solution that equips the city of Leiria with a robust tool for smart urban mobility.

**Keywords**: Urban Mobility, GTFS, PostGIS, FastAPI, Flutter, SaaS, Geographic Information Systems (GIS).

---

## 1. Introdução

O presente capítulo serve de enquadramento inicial ao projeto Go with Mobilis, apresentando o tema do trabalho, a sua justificação, os objetivos delineados, os métodos aplicados e a organização estrutural deste documento.

### 1.1. Objeto e Justificação do Trabalho
O objeto deste trabalho é o desenvolvimento do Go with Mobilis, um ecossistema digital constituído por uma aplicação móvel para passageiros (Flutter), uma API backend (FastAPI) e uma base de dados geoespacial na nuvem (PostgreSQL/PostGIS) estruturada segundo a norma de transportes GTFS.
A justificação deste tema reside na necessidade de modernizar o acesso à informação da rede de autocarros Mobilis em Leiria, substituindo tabelas horárias estáticas por uma consulta geográfica interativa. O projeto adota uma filosofia académica de código aberto, sustentável e gratuita, assegurando independência de custos de licenciamento direto de APIs de mapas nativas e foco na privacidade.

### 1.2. Objetivos do Trabalho
Desenvolver e colocar em produção uma plataforma integrada que centralize e georreferencie os horários, rotas e alertas da rede Mobilis, fornecendo uma consulta fluida em tempo útil a utilizadores passageiros e operadores administrativos.

**Objetivos Específicos:**
* Normalizar os dados de trânsito em conformidade com o padrão GTFS.
* Processar dados espaciais (paragens próximas e trajetos) eficientemente via base de dados PostGIS.
* Construir uma API REST assíncrona com autenticação segura por tokens JWT.
* Criar uma app móvel reativa (Android/iOS) com gestão de estado isolada via padrão BLoC.
* Garantir a resiliência offline através do armazenamento local de panfletos PDF em cache.
* Disponibilizar uma consola móvel para que os administradores possam gerir alertas de trânsito e o estado das linhas em tempo real.

---

## 2. Estado da Arte e Benchmarks

### 2.1. Análise de Soluções de Mercado (Benchmarks)
A tabela seguinte resume as principais soluções comerciais e o seu posicionamento face ao ecossistema proposto:

| Plataforma | Foco Principal | Grande Diferencial (2026) | Ponto Fraco / Limitação |
| :--- | :--- | :--- | :--- |
| **Google/Apple Maps** | Navegação Global | IA preditiva (eficiência energética e pegada de carbono). | Lacunas em operadores pequenos fora das grandes cidades. |
| **Moovit** | Transporte Público | Crowdsourcing e alertas em tempo real da comunidade. | Interface com muito ruído visual focado em ads/comunidade. |
| **Moov-u** | Operadores Locais | Transação direta (compra de bilhetes e passes via MB WAY). | Foco restrito a operadores específicos (Tejo, Oeste, Lis). |

### 2.2. Benchmarks Académicos

| Projeto | Instituição | Tecnologia Chave | Objetivo Principal |
| :--- | :--- | :--- | :--- |
| **OneBusAway** | Univ. Washington | Open-source / API REST | Criar um padrão global para dados de transporte em tempo real. |
| **Smart Campus** | Univ. Aveiro | Sensores IoT em paragens | Eliminar o tempo de espera passivo dos alunos no campus. |
| **Living Lab** | Nova SBE | Gestão de frotas dinâmica | Sincronizar autocarros (shuttles) com comboios da CP. |

---

## 3. Planeamento e Requisitos do Sistema

### 3.1. Requisitos Funcionais (RF)

| ID | Descrição | Prioridade |
| :--- | :--- | :--- |
| **APP-RF-01** | O sistema DEVE permitir o registo e a autenticação (login) de utilizadores para sincronização de dados. | Alta |
| **APP-RF-02** | O sistema DEVE apresentar a visualização de linhas, horários e trajetos no mapa. | Alta |
| **APP-RF-03** | O sistema DEVE identificar as paragens mais próximas com base no GPS do dispositivo. | Alta |
| **APP-RF-04** | O sistema DEVE permitir ao utilizador marcar e gravar linhas e paragens como favoritos. | Média |
| **APP-RF-05** | O sistema DEVE apresentar avisos e alertas gerais de trânsito ativos. | Alta |
| **SYS-RF-01** | O servidor DEVE fornecer endpoints para enviar a lista de horários, rotas e paragens próximas. | Alta |
| **SYS-RF-02** | O servidor DEVE persistir a lista de utilizadores e favoritos sincronizados na nuvem. | Média |
| **ADM-RF-01** | O painel de admin na app DEVE permitir criar, editar e apagar alertas de trânsito em tempo real. | Alta |
| **ADM-RF-02** | O painel de admin na app DEVE permitir ativar/desativar linhas existentes e visualizar estatísticas gerais. | Média |

### 3.2. Requisitos Não Funcionais (RNF)

| ID | Descrição | Prioridade |
| :--- | :--- | :--- |
| **APP-RNF-PORT** | **Portabilidade**: Aplicação móvel multiplataforma desenvolvida em Flutter (Android/iOS). | Alta |
| **APP-RNF-FIAB** | **Cache/Offline**: Acesso a panfletos PDF locais e paragens cached mesmo sem internet. | Alta |
| **SYS-RNF-DESEMP** | **Desempenho**: Processamento espacial instantâneo de proximidade na base de dados (PostGIS). | Alta |
| **SYS-RNF-INTER** | **Interoperabilidade**: Modelo relacional do transporte estruturado sob o padrão GTFS. | Alta |
| **SYS-RNF-PRIV** | **Privacidade**: Não rastrear dados pessoais dos utilizadores para fins comerciais. | Média |
| **SYS-RNF-DOC** | **Autodocumentação**: Backend com interface de testes gerada automaticamente (Swagger). | Média |

---

## 4. Análise e Casos de Uso

### 4.1. Diagrama de Casos de Uso
O sistema interage com dois atores: o **Passageiro** (ator ativo que consulta o mapa, rotas e guarda favoritos) e o **Administrador** (utilizador promovido com acesso ao menu de monitorização, controlo de linhas e gestão de alertas de trânsito). O **Servidor Backend** atua como ator passivo respondendo aos pedidos HTTP.

### 4.2. Especificação Textual dos Casos de Uso Críticos

#### CASO DE USO 1: Autenticar Passageiro
* **Ator(es)**: Passageiro, Servidor Backend.
* **Objetivo**: Permitir que o utilizador inicie sessão na aplicação para sincronizar os seus favoritos.
* **Cenário Principal**:
  1. O Passageiro seleciona "Iniciar Sessão" na aplicação.
  2. O Sistema apresenta o formulário.
  3. O Passageiro insere e-mail e palavra-passe.
  4. O Sistema valida as credenciais com o servidor que devolve um token JWT seguro.
  5. A app persiste o token e apresenta mensagem de sucesso.
* **Cenários Alternativos**:
  * *4.1. Credenciais inválidas*: O sistema exibe mensagem de erro e limpa os campos.
  * *4.2. Falha de ligação*: O sistema alerta sobre a indisponibilidade de rede e permite navegação offline.

#### CASO DE USO 2: Adicionar Favorito
* **Ator(es)**: Passageiro.
* **Pré-condições**: O utilizador está autenticado e a visualizar uma paragem/linha.
* **Cenário Principal**:
  1. O Passageiro clica no botão de favorito.
  2. O Sistema regista na base de dados local e envia o pedido HTTP para sincronizar na nuvem.
  3. O Sistema exibe confirmação.
* **Cenários Alternativos**:
  * *2.1. Utilizador não autenticado*: O sistema redireciona para a página de login/registo e retoma o fluxo após sucesso.
  * *3.1. Sem ligação de rede (Modo Offline)*: O favorito é armazenado localmente em cache para ser sincronizado quando a ligação for restabelecida.

---

## 5. Análise de Tecnologias e Decisões Finais

### 5.1. Comparativo Técnico

#### Mobile (Frontend)
* **Android Nativo (Kotlin)**: Performance máxima e acesso direto a APIs de hardware, contudo obriga a duplicar o código para iOS.
* **Flutter (Dart) - Escolhido**: Desenvolvimento multiplataforma real (Android e iOS) a partir de um único código-base com excelente renderização de interfaces geográficas (motor Skia/Impeller) e gestão de estado via BLoC.

#### Backend
* **Node.js (Express)**: Elevada performance assíncrona para I/O, mas limitado em processamento numérico e tratamento SIG estruturado.
* **Python (FastAPI) - Escolhido**: Sintaxe limpa, validação via Pydantic, geração automática de Swagger para testes ágeis e excelente compatibilidade com bibliotecas geoespaciais e SQLAlchemy ORM.

#### Base de Dados
* **MySQL**: Simples para prototipagem rápida, mas com suporte geoespacial limitado e perda de desempenho em relações complexas.
* **PostgreSQL + PostGIS - Escolhido**: Referência da indústria SIG. Processamento nativo de geometrias geográficas (raio de proximidade e trajetos) e robustez ideal para os dados normalizados do padrão GTFS.

#### Mapas
* **Google Maps SDK**: Altamente detalhado, porém dependente de chaves de API proprietárias pagas e restrições de controlo de dados.
* **flutter_map (Google Tiles & CartoDB) - Escolhido**: Integração híbrida. Consome *tiles* rasterizados públicos e gratuitos do Google Maps (Modo Claro) e do CartoDB (Modo Escuro), eliminando custos de licenciamento, garantindo privacidade e mantendo a familiaridade visual dos utilizadores.

---

## 6. Desenvolvimento da Camada Cliente (Mobile Frontend)

A camada cliente do projeto foi implementada em **Flutter (Dart)** sob uma arquitetura de separação de conceitos estruturada na diretoria `lib/`:
* `services/`: Comunicação de rede (API Client), serviços GPS e gestão de cache.
* `blocs/`: Lógica de negócio e controlo reativo dos estados.
* `screens/`: Componentes visuais e ecrãs (UI).

```
lib/
├── services/   # api_service.dart, location_service.dart, translation_service.dart
├── blocs/      # BLoC state classes
├── screens/    # passenger_map_screen.dart, admin_panel_screen.dart, login_screen.dart
└── main.dart   # Ponto de entrada
```

### 6.1. Gestão de Estado (BLoC Pattern)
A comunicação entre ecrãs e serviços é mediada pelo padrão **BLoC**. Os ecrãs disparam eventos (`Events`) e reagem dinamicamente aos estados emitidos (`States`), como `StateLoading`, `StateSuccess` e `StateError`. Isto mantém a lógica de negócio isolada dos componentes gráficos, simplificando os testes unitários.

### 6.2. Visualização Cartográfica
O widget do mapa (`flutter_map`) exibe de forma reativa:
1. **Camada de Azulejos (TileLayer)**: Carrega de forma dinâmica as imagens de mapa em alta definição (Google Maps em modo claro; CartoDB Dark Matter em modo escuro).
2. **Camada de Trajetos (PolylineLayer)**: Desenha as linhas coloridas oficiais da rota a partir das coordenadas `LINESTRING` retornadas pela API. Adicionalmente, desenha linhas pontilhadas azuis para representar o percurso pedonal (caminhada).
3. **Camada de Marcadores (MarkerLayer)**: Posiciona círculos brancos com bordas pretas representando as paragens intermédias da viagem e marcadores específicos para a localização em tempo real do utilizador.

### 6.3. Estrutura de Ecrãs da Aplicação
* **Ecrã do Mapa (`passenger_map_screen.dart`)**: Integra o mapa interativo com painéis deslizantes (`DraggableScrollableSheet`) que exibem as paragens mais próximas, tempos de espera decrescentes atualizados dinamicamente via temporizador de 15 segundos, e a alteração automática para o estado **"Em viagem"** ao embarcar no autocarro.
* **Autenticação e Perfil**: Ecrãs de login, registo e gestão de perfil. O registo obriga o utilizador a validar a sua conta por e-mail antes do login. O perfil permite capturar e sincronizar fotos em base64.
* **Horários e Consulta de Linhas**: Ecrãs dedicados que organizam as tabelas de horários por sentido (Ida/Volta) e tipo de dia (Dias úteis, sábados e domingos/feriados).
* **Leitor PDF Offline (`pdf_viewer_screen.dart`)**: Permite a abertura de horários oficiais em PDF. Os ficheiros abertos uma vez são mantidos em cache local (`pdf_cache_service.dart`) para consulta futura offline.
* **Painel de Administração (`admin_panel_screen.dart`)**: Acessível apenas a contas com `is_admin = true`. Implementa:
  1. *Visão Geral*: Indicadores de utilizadores e favoritos ativos na plataforma.
  2. *Linhas*: Lista de rotas com possibilidade de as ativar/desativar em tempo real.
  3. *Utilizadores*: Procura de utilizadores e comutador para promoção a administrador.
  4. *Alertas*: CRUD completo de avisos de trânsito em Leiria (criação, edição e eliminação).

---

## 7. Desenvolvimento do Backend e Persistência

O backend (FastAPI) gere utilizadores, processa dados do PostGIS e fornece endpoints estruturados in JSON para o cliente Flutter.

### 7.1. Estrutura GTFS (ORM SQLAlchemy)
A modelagem segue a especificação internacional:
* **Agency**: Configuração do operador Mobilis.
* **Route**: Registo das linhas, nomes e respetivas cores.
* **Trip & StopTime**: Viagens planeadas e a sua correspondente passagem cronológica e ordenada por cada paragem.
* **Stop**: Representação física da paragem (mapeada com geometria PostGIS `POINT`).
* **Shape**: Traçado exato composto por múltiplos pontos geográficos (PostGIS `LINESTRING`).
* **Calendar**: Registo dos dias e períodos de circulação ativa de cada serviço.

### 7.2. Lógica Geoespacial (PostGIS)
* **Paragens Próximas**: A API recebe a latitude/longitude do GPS do utilizador e executa na base de dados a query espacial via `ST_DWithin` para obter apenas paragens no raio próximo (ex: 500m), ordenando-as instantaneamente pela distância linear obtida via `ST_Distance` com suporte de índices espaciais `GiST`.
* **Trajetos**: As geometrias `LINESTRING` são processadas na base de dados e devolvidas como coleções simplificadas de coordenadas geográficas no formato JSON para desenho instantâneo no mapa móvel.

### 7.3. Fluxos de Dados Principais

#### Autenticação Segura
O utilizador insere as credenciais. O backend valida a estrutura do e-mail com o Pydantic, acede à tabela `users` do Neon, compara a palavra-passe inserida com o hash armazenado (usando **bcrypt** via **Passlib**) e, em caso de sucesso, emite um token **JWT** assinado (algoritmo **HS256**) que codifica as permissões da conta. A sessão do utilizador é blindada nas rotas administrativas por dependências de injeção direta que validam as claims do token.

#### Notificações Híbridas e E-mails (Brevo SaaS)
Para ultrapassar as restrições de bloqueio SMTP (portas 465/587) nos servidores cloud do Render, o módulo `email_service.py` dispõe de uma arquitetura adaptativa:
1. **Canal Principal (API REST HTTP)**: Quando a variável `BREVO_API_KEY` está presente, o e-mail é encapsulado num payload JSON e submetido via pedido `POST` seguro para o servidor da Brevo, garantindo 100% de taxa de entrega direta na caixa de entrada.
2. **Canal de Fallback (SMTP)**: Tenta a entrega convencional em TLS caso a chave de API não esteja configurada.

Este serviço envia o e-mail com o link de ativação da conta (contendo um token alfanumérico seguro de uso único). Ao clicar, o utilizador abre o link no seu e-mail, e o link dispara um pedido GET HTTPS que valida o token, ativa a conta para verificada e devolve uma página HTML formatada com estilo CSS *premium* confirmando o sucesso.

#### Administração e Sincronização
* **CRUD API**: O backend disponibiliza endpoints completos para criação e edição de linhas, paragens e horários. Embora a app Flutter exponha apenas as funções do painel admin simplificado (alertas, ativação rápida de linhas e promoção de utilizadores), a API de backend garante compatibilidade para futuras expansões e integrações de bases de dados.
* **Importação GTFS**: Os scripts `import_gtfs.py`, `import_all_gtfs.py` e `fix_shapes.py` lêem ficheiros GTFS, transformam as coordenadas decimais em geometrias binárias PostGIS e inserem-nas no banco de dados Neon sob uma transação SQL com rollback seguro.

---

## 8. Infraestrutura e Deployment Contínuo (CI/CD)

A arquitetura física está hospedada inteiramente em plataformas cloud SaaS gratuitas com processos automatizados de integração e entrega contínua a partir de um repositório GitHub:

```
[Repositório GitHub] ---> (Push Trigger) ---> [Render Cloud Engine]
                                                    | (SSL / TLS)
                                             [Neon Serverless Postgres]
                                                    | (SSL / TLS mode=require)
                                             [Brevo Rest API Mailer]
```

* **Backend FastAPI (Render.com)**: Alojado como *Web Service* do Render. Cada alteração integrada no branch `main` do GitHub dispara automaticamente o build do backend (`pip install -r requirements.txt`) e efetua o deploy sem interrupção de serviço (*Zero-Downtime Deployment*).
* **Base de Dados PostgreSQL (Neon.tech)**: Instância serverless geograficamente localizada na Europa Central (Frankfurt) para garantir baixa latência. Conta com suspensão automática por inatividade (*Scale-to-Zero*) para manter custos nulos. A ligação entre o backend e a base de dados do Neon é forçada a utilizar a diretiva `sslmode=require` para segurança completa dos dados em trânsito.
* **Envio de E-mails (Brevo SaaS)**: Responsável pela entrega de e-mails transacionais via pedidos POST HTTP, garantindo integridade e reputação.
* **Alojamento Web (Netlify)**: Configurado com webhooks automáticos do repositório para o deployment dinâmico de landings ou painéis estáticos complementares.
