# Videira Dental Clinic — ROADMAP.md
> Lista completa de tarefas organizadas em fases.  
> Copiar para o projeto e marcar conforme avança.  
> Última atualização: Abril 2026

---

## Como usar

- Marque `[x]` ao concluir cada tarefa
- Cada tarefa tem um **prompt pronto** para usar com IA (Claude, LibreChat)
- Siga a ordem — cada fase depende da anterior

---

## FASE 0 — Ambiente local

### 0.1 Pré-requisitos no sistema

- [ ] Ruby 3.3+ instalado (`ruby -v`)
- [ ] Rails 7.2+ instalado (`rails -v`)
- [ ] PostgreSQL instalado e rodando (`psql --version`)
- [ ] Redis instalado e rodando (`redis-cli ping` → PONG)
- [ ] Node.js 18+ instalado (`node -v`)
- [ ] Git configurado (`git config --global user.name`)
- [ ] Docker instalado (para LibreChat + Ollama)

### 0.2 Criar o projeto Rails

```bash
rails new videira_dental \
  --database=postgresql \
  --css=tailwind \
  --skip-jbuilder \
  --skip-test \
  -T
cd videira_dental
```

> **Prompt IA:** "Dentro do contexto da Videira Dental Clinic (CONTEXT.md), revise o comando `rails new` e confirme se as flags estão corretas para o stack definido: PostgreSQL, Tailwind, Hotwire, sem jbuilder, sem minitest."

### 0.3 Configurar PostgreSQL com UUID

- [ ] Criar banco de dados: `rails db:create`
- [ ] Habilitar extensão pgcrypto no migration inicial:

```ruby
# db/migrate/TIMESTAMP_enable_pgcrypto.rb
class EnablePgcrypto < ActiveRecord::Migration[7.2]
  def change
    enable_extension 'pgcrypto'
  end
end
```

- [ ] Em `config/application.rb`, definir UUID como PK padrão:

```ruby
config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
```

### 0.4 Instalar todas as gems

- [ ] Adicionar ao `Gemfile`:

```ruby
# Autenticação
gem 'devise'
gem 'omniauth-google-oauth2'
gem 'omniauth-rails_csrf_protection'

# Autorização
gem 'pundit'

# Pagamento
gem 'mercadopago'

# Jobs assíncronos
gem 'sidekiq'
gem 'redis'

# Paginação
gem 'pagy'

# Auditoria
gem 'paper_trail'

# Variáveis de ambiente
gem 'dotenv-rails', groups: [:development, :test]

group :development, :test do
  gem 'factory_bot_rails'
  gem 'faker'
end
```

- [ ] Rodar `bundle install`

### 0.5 Configurar variáveis de ambiente

- [ ] Criar arquivo `.env` na raiz do projeto:

```bash
# .env (nunca versionar — já está no .gitignore)

# Banco
DATABASE_URL=postgresql://localhost/videira_dental_development

# MercadoPago (pegar no painel sandbox do MP)
MERCADOPAGO_ACCESS_TOKEN=TEST-xxxx
MERCADOPAGO_PUBLIC_KEY=TEST-xxxx
MERCADOPAGO_WEBHOOK_SECRET=xxxx

# Google OAuth (pegar no Google Cloud Console)
GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=xxxx

# App
APP_HOST=localhost:3000
SECRET_KEY_BASE=  # gerado pelo Rails
```

- [ ] Confirmar que `.env` está no `.gitignore`

---

## FASE 1 — Banco de dados e Models

### 1.1 Migrations (nesta ordem exata)

- [ ] **Clinic**
```bash
rails g migration CreateClinics name:string slug:string:uniq owner_email:string
```

- [ ] **Users** (Devise vai gerar — customizar depois)
```bash
rails g devise:install
rails g devise User
# Adicionar manualmente: clinic_id:references, name, phone, cro_number,
#                        specialty, birth_date:date, avatar_url, role:integer, google_uid
```

- [ ] **Rooms**
```bash
rails g migration CreateRooms clinic:references name:string description:text
```

- [ ] **Availabilities**
```bash
rails g migration CreateAvailabilities room:references created_by:references \
  date:date starts_at:time ends_at:time price:decimal booked:boolean
```

- [ ] **DiscountRules**
```bash
rails g migration CreateDiscountRules clinic:references min_slots:integer \
  discount_percent:decimal active:boolean
```

- [ ] **BookingGroups**
```bash
rails g migration CreateBookingGroups user:references clinic:references \
  discount_rule:references subtotal:decimal discount_percent:decimal \
  discount_amount:decimal total:decimal status:integer
```

- [ ] **Bookings**
```bash
rails g migration CreateBookings booking_group:references availability:references \
  user:references status:integer cancel_reason:text cancelled_at:datetime
```

- [ ] **Payments**
```bash
rails g migration CreatePayments booking_group:references provider:string \
  provider_id:string pix_code:text pix_qr_url:string status:integer \
  amount:decimal expires_at:datetime paid_at:datetime
```

- [ ] **PaperTrail versions table**
```bash
rails generate paper_trail:install --with-changes
```

- [ ] Rodar todas as migrations: `rails db:migrate`

> **Prompt IA:** "Dentro do contexto da Videira Dental Clinic (CONTEXT.md seção 7), revise as migrations geradas e garanta que: todas usam UUID como PK, as FKs estão corretas, os enums estão como integer, e o campo `booked` tem default false."

### 1.2 Models

- [ ] **Clinic** (`app/models/clinic.rb`)
  - `has_many :users`
  - `has_one :room`
  - `has_many :discount_rules`
  - Validações: `name`, `slug` (único), `owner_email`

- [ ] **User** (`app/models/user.rb`)
  - `belongs_to :clinic`
  - `has_many :booking_groups`
  - `has_many :bookings`
  - `has_many :availabilities, foreign_key: :created_by_id`
  - `enum role: { owner: 0, dentist: 1 }`
  - `has_paper_trail`
  - Devise modules: `:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :omniauthable`
  - Validações: `name`, `email`, `cro_number` (obrigatório para dentist)

- [ ] **Room** (`app/models/room.rb`)
  - `belongs_to :clinic`
  - `has_many :availabilities`
  - Validações: `name`

- [ ] **Availability** (`app/models/availability.rb`)
  - `belongs_to :room`
  - `belongs_to :created_by, class_name: 'User'`
  - `has_one :booking`
  - `has_paper_trail`
  - Validações: `date`, `starts_at`, `ends_at`, `price`
  - Scope: `available` (booked: false), `for_date(date)`

- [ ] **DiscountRule** (`app/models/discount_rule.rb`)
  - `belongs_to :clinic`
  - `has_many :booking_groups`
  - `has_paper_trail`
  - Scope: `active`
  - Método de classe: `best_for(quantity)` — retorna a melhor regra para N slots

- [ ] **BookingGroup** (`app/models/booking_group.rb`)
  - `belongs_to :user`
  - `belongs_to :clinic`
  - `belongs_to :discount_rule, optional: true`
  - `has_many :bookings`
  - `has_one :payment`
  - `enum status: { pending: 0, confirmed: 1, expired: 2, cancelled: 3 }`
  - `has_paper_trail`

- [ ] **Booking** (`app/models/booking.rb`)
  - `belongs_to :booking_group`
  - `belongs_to :availability`
  - `belongs_to :user`
  - `enum status: { pending: 0, confirmed: 1, cancelled: 2 }`
  - `has_paper_trail`
  - Validação de cancelamento: `availability.date - 48.hours > Time.current`

- [ ] **Payment** (`app/models/payment.rb`)
  - `belongs_to :booking_group`
  - `enum status: { pending: 0, paid: 1, expired: 2 }`
  - `has_paper_trail`

> **Prompt IA:** "Dentro do contexto da Videira Dental Clinic (CONTEXT.md seção 6 e 7), gere o model BookingGroup completo com: associations, enums, validações, has_paper_trail, e o método `confirm!` que confirma o grupo e todos os bookings filhos."

### 1.3 Seeds

- [ ] Criar `db/seeds.rb` com:
  - 1 Clinic (Videira Dental)
  - 1 User owner (email da dona)
  - 1 Room
  - 3 DiscountRules (2 slots = 5%, 3 slots = 10%, 5 slots = 15%)
  - 10 Availabilities nos próximos 30 dias para teste

```bash
rails db:seed
```

---

## FASE 2 — Autenticação

### 2.1 Devise base

- [ ] Rodar `rails g devise:views` e customizar para o design do Figma
- [ ] Customizar `app/views/devise/sessions/new.html.erb` (tela Login)
- [ ] Customizar `app/views/devise/registrations/new.html.erb` (tela Cadastro)
- [ ] Configurar campos extras no Devise: `name`, `phone`, `cro_number`, `specialty`
- [ ] Em `ApplicationController`: `before_action :configure_permitted_parameters, if: :devise_controller?`

### 2.2 Google OAuth

- [ ] Criar projeto no [Google Cloud Console](https://console.cloud.google.com)
- [ ] Habilitar Google+ API / Google Identity
- [ ] Criar credenciais OAuth 2.0 → Web application
- [ ] Authorized redirect URI: `http://localhost:3000/users/auth/google_oauth2/callback`
- [ ] Copiar `GOOGLE_CLIENT_ID` e `GOOGLE_CLIENT_SECRET` para `.env`
- [ ] Configurar OmniAuth em `config/initializers/devise.rb`
- [ ] Criar `Users::OmniauthCallbacksController`
- [ ] Método `User.from_omniauth(auth)` no model
- [ ] Adicionar botão "Entrar com Google" nas views

> **Prompt IA:** "Dentro do contexto da Videira Dental Clinic, gere o método `User.from_omniauth(auth)` que: encontra ou cria usuário pelo google_uid, define role como dentist, associa à única Clinic existente (para o MVP), e lida com o caso de email já existente."

### 2.3 Pundit — Políticas de Autorização

- [ ] `rails g pundit:install`
- [ ] Criar `app/policies/availability_policy.rb`
  - `owner?` → create, update, destroy
  - `dentist?` → index, show
- [ ] Criar `app/policies/booking_group_policy.rb`
  - `dentist?` → create, show
  - `owner?` → index, show, update
- [ ] Criar `app/policies/admin/user_policy.rb`
  - Somente `owner?` → index, show, update
- [ ] Criar `app/policies/discount_rule_policy.rb`
  - Somente `owner?` → all actions
- [ ] Em `ApplicationController`: `include Pundit::Authorization`

---

## FASE 3 — Frontend base

### 3.1 Design system

- [ ] Importar fonte Prompt em `app/assets/stylesheets/application.css`:
```css
@import url('https://fonts.googleapis.com/css2?family=Prompt:wght@300;400;500;600;700&display=swap');
```

- [ ] Adicionar CSS variables do tema (copiar da seção 2 do DESIGN_SYSTEM.md)
- [ ] Configurar `tailwind.config.js` com as cores do projeto:

```js
module.exports = {
  content: ['./app/views/**/*.html.erb', './app/javascript/**/*.js'],
  theme: {
    extend: {
      colors: {
        background: '#fef8e1',
        primary:    '#5D4037',
        secondary:  '#8D6E63',
        accent:     '#C9B8A8',
        foreground: '#3E2723',
        pix:        '#32BCAD',
      },
      fontFamily: {
        sans: ['Prompt', 'sans-serif'],
      },
      borderRadius: {
        DEFAULT: '0.625rem',
      },
    },
  },
}
```

### 3.2 Layouts

- [ ] Customizar `app/views/layouts/application.html.erb` (layout público)
- [ ] Criar `app/views/layouts/admin.html.erb` (layout admin com grid de navegação)
- [ ] Criar partials reutilizáveis:
  - `app/views/shared/_avatar.html.erb`
  - `app/views/shared/_back_button.html.erb`
  - `app/views/shared/_flash.html.erb`
  - `app/views/shared/_logo.html.erb`

### 3.3 Controllers Stimulus base

- [ ] `app/javascript/controllers/countdown_controller.js` (timer do Pix)
- [ ] `app/javascript/controllers/clipboard_controller.js` (copiar chave Pix)
- [ ] `app/javascript/controllers/flash_controller.js` (auto-dismiss de alertas)
- [ ] `app/javascript/controllers/phone_mask_controller.js` (máscara de telefone)
- [ ] `app/javascript/controllers/week_selector_controller.js` (navegação semanal)
- [ ] `app/javascript/controllers/modal_controller.js` (abrir/fechar modais)
- [ ] `app/javascript/controllers/cart_controller.js` (carrinho de slots)

---

## FASE 4 — Funcionalidades da Dentista

### 4.1 Home — Agenda de slots

- [ ] `HomeController#index` → carrega slots do dia atual
- [ ] View `home/index.html.erb`:
  - Header com Logo + ícone carrinho (se autenticada) ou Avatar (se não)
  - Grid de navegação 2×2 (Cadastro, Reservas, Carteira→remover, Shop→remover)
  - Seletor de semana (navegação por semana)
  - Botão de calendário completo
  - Lista de slots do dia selecionado
  - Barra inferior fixa quando há slots selecionados
- [ ] Turbo Frame `#slots` para atualizar lista ao trocar de data sem reload

> **Prompt IA:** "Dentro do contexto da Videira Dental Clinic, gere o HomeController#index que: busca availabilities da room da clínica para a data selecionada (params[:date] || Date.tomorrow), filtra apenas as não reservadas (booked: false), e expõe @availabilities e @selected_date para a view."

### 4.2 Carrinho de slots (Turbo Frame)

- [ ] Turbo Frame `#cart` no layout para persistir carrinho entre navegações
- [ ] `CartController` com actions: `add`, `remove`, `clear`
- [ ] Sessão ou cookies para persistir slots selecionados antes do login
- [ ] `app/views/shared/_booking_cart.html.erb` com resumo + desconto + total

### 4.3 Tela de confirmação (BookingGroup)

- [ ] `BookingGroupsController#new` → mostra slots do carrinho + desconto calculado
- [ ] Service `DiscountCalculator.call(slots, clinic)` → retorna regra e valores
- [ ] `BookingGroupsController#create` → cria BookingGroup + Bookings + Payment
- [ ] View `booking_groups/new.html.erb`:
  - Resumo dos slots (data, horário, valor unitário)
  - Badge de desconto se aplicável
  - Total final
  - Botão "Pagar com Pix"

> **Prompt IA:** "Dentro do contexto da Videira Dental Clinic, gere o service DiscountCalculator com o método `.call(availability_ids, clinic)` que: soma os preços dos slots, busca a melhor DiscountRule ativa da clínica para a quantidade, calcula subtotal/discount_amount/total, e retorna um hash com esses valores."

### 4.4 Pagamento Pix

- [ ] `PaymentsController#show` → exibe QR Code Pix
- [ ] Integração com MercadoPago: criar preferência com Pix
- [ ] `MercadoPagoService.create_pix(booking_group)` → retorna `pix_code` e `pix_qr_url`
- [ ] View `payments/show.html.erb`:
  - QR Code como imagem
  - Countdown timer (Stimulus)
  - Botão copiar chave Pix (Stimulus + clipboard)
  - Turbo Stream polling do status
- [ ] Turbo Stream broadcast quando webhook confirmar

> **Prompt IA:** "Dentro do contexto da Videira Dental Clinic, gere o MercadoPagoService com o método `.create_pix(booking_group)` que: usa a gem mercadopago, cria uma preference com os dados do BookingGroup, define notification_url para o webhook, expires_at em 30 minutos, e retorna pix_code e pix_qr_url."

### 4.5 Webhook MercadoPago

- [ ] `WebhooksController#mercadopago` (rota POST `/webhooks/mercadopago`)
- [ ] Validar assinatura do webhook
- [ ] Ao receber `payment.updated` com status `approved`:
  - Atualizar `Payment#paid_at`, `Payment#status → paid`
  - Confirmar `BookingGroup#status → confirmed`
  - Confirmar todos os `Booking#status → confirmed`
  - Marcar `Availability#booked → true`
  - Broadcast Turbo Stream para a tela de pagamento
- [ ] Adicionar rota no `config/routes.rb` sem CSRF protection

### 4.6 Sidekiq — Expiração de pagamentos

- [ ] Criar `app/jobs/expire_payments_job.rb`
- [ ] Lógica: busca Payments pending com `expires_at < Time.current`
- [ ] Para cada payment expirado:
  - `Payment#status → expired`
  - `BookingGroup#status → expired`
  - Todos os `Booking#status → cancelled`
  - Todas as `Availability#booked → false`
- [ ] Agendar job recorrente a cada 5 minutos no `config/sidekiq.yml`
- [ ] Configurar Redis em `config/initializers/sidekiq.rb`

### 4.7 Cancelamento de booking

- [ ] `BookingsController#cancel` (PATCH `/bookings/:id/cancel`)
- [ ] Verificar se `availability.starts_at - 48.hours > Time.current`
- [ ] Se sim: atualizar status, `cancelled_at`, `cancel_reason`
- [ ] Se não: retornar erro com mensagem explicativa
- [ ] Liberar slot: `availability.update!(booked: false)`

### 4.8 Tela Minhas Reservas

- [ ] `BookingsController#index` → lista BookingGroups da dentista logada
- [ ] Ordenar por data desc, agrupar por mês
- [ ] Mostrar status de cada grupo (pending, confirmed, cancelled, expired)
- [ ] Link para detalhes + opção de cancelar (se elegível)

### 4.9 Tela de Perfil/Conta

- [ ] `UsersController#show` → dados da dentista logada
- [ ] `UsersController#update` → editar nome, telefone, CRO, especialidade, foto
- [ ] Upload de avatar (ActiveStorage + `has_one_attached :avatar`)

---

## FASE 5 — Painel Admin (Owner)

### 5.1 Disponibilidade (slots)

- [ ] `Admin::AvailabilitiesController` (CRUD completo)
- [ ] `admin/availabilities/index.html.erb`:
  - Seletor de semana (mesmo componente da Home)
  - Lista de slots do dia com status (livre/reservado)
  - Botão "Adicionar turno"
- [ ] Modal de criação: data, starts_at, ends_at, price
- [ ] Modal de edição: mesmos campos
- [ ] Modal de confirmação de exclusão (só se não estiver reservado)

> **Prompt IA:** "Dentro do contexto da Videira Dental Clinic, gere o Admin::AvailabilitiesController com as actions index, new, create, edit, update e destroy. O controller deve: usar Pundit para autorização, escopo sempre pela clinic da owner logada, impedir destroy se availability.booked for true."

### 5.2 Regras de Desconto

- [ ] `Admin::DiscountRulesController` (CRUD)
- [ ] `admin/discount_rules/index.html.erb`:
  - Tabela de regras ativas (min_slots, discount_percent)
  - Toggle ativo/inativo
  - Botão adicionar nova regra

### 5.3 Reservas

- [ ] `Admin::BookingsController#index` → todas as reservas da clínica
- [ ] Filtro por data (seletor de semana)
- [ ] Mostrar: dentista, data, horário, valor, status
- [ ] Modal de edição de reserva

### 5.4 Clientes (dentistas)

- [ ] `Admin::UsersController#index` → lista de dentistas
- [ ] Busca por nome ou CRO
- [ ] `Admin::UsersController#show` → detalhes com abas:
  - **Dados** — formulário editável (sem email)
  - **Reservas** — histórico de BookingGroups
  - **Histórico** — PaperTrail versions

### 5.5 PaperTrail — Histórico de alterações

- [ ] Configurar `whodunnit` em `ApplicationController`:
```ruby
before_action :set_paper_trail_whodunnit

def user_for_paper_trail
  current_user&.id
end
```
- [ ] View parcial `_versions_table.html.erb`:
  - Coluna: quando, quem, campo alterado, valor anterior, valor novo
- [ ] Incluir na aba "Histórico" das telas de detalhes

---

## FASE 6 — Deploy

### 6.1 Preparação

- [ ] Adicionar `gem 'pg'` no grupo production (já deve estar)
- [ ] Configurar `config/master.key` e credentials
- [ ] Definir `SECRET_KEY_BASE` nas variáveis do servidor
- [ ] Compilar assets: `rails assets:precompile`
- [ ] Criar `Procfile` para Render/Fly.io:

```
web: bundle exec rails server -p $PORT
worker: bundle exec sidekiq
release: bundle exec rails db:migrate
```

### 6.2 Escolher plataforma

Opções recomendadas:

| Plataforma | Custo MVP | Facilidade | Recomendação |
|-----------|-----------|------------|--------------|
| **Render** | Grátis (limitado) / $7/mês | ⭐⭐⭐⭐⭐ | ✅ Melhor para começar |
| **Fly.io** | $0 (free tier) | ⭐⭐⭐⭐ | Boa opção |
| **Railway** | $5/mês | ⭐⭐⭐⭐⭐ | Simples e rápido |

- [ ] Criar conta na plataforma escolhida
- [ ] Conectar repositório GitHub
- [ ] Configurar variáveis de ambiente (as mesmas do `.env`)
- [ ] Configurar Redis (Render Redis / Upstash)
- [ ] Configurar PostgreSQL (Render Postgres)
- [ ] Configurar webhook URL do MercadoPago para o domínio de produção

---

## FASE 7 — IA local (LibreChat + Ollama)

### 7.1 Setup Docker

- [ ] Criar `docker-compose.yml` na raiz:

```yaml
version: '3.8'
services:
  ollama:
    image: ollama/ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama

  librechat:
    image: ghcr.io/danny-avila/librechat:latest
    ports:
      - "3080:3080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    depends_on:
      - ollama
    volumes:
      - librechat_data:/app/data

volumes:
  ollama_data:
  librechat_data:
```

- [ ] Rodar: `docker compose up -d`
- [ ] Baixar modelo: `docker exec ollama ollama pull llama3`
- [ ] Acessar LibreChat em `http://localhost:3080`

### 7.2 Configurar papéis de IA

- [ ] Criar Preset "Senior Rails Engineer" no LibreChat (prompt da seção 12 do CONTEXT.md)
- [ ] Criar Preset "System Architect"
- [ ] Criar Preset "Code Reviewer"
- [ ] Fixar o CONTEXT.md como mensagem de sistema em cada preset

---

## Ordem recomendada de execução

```
Fase 0 (1-2h) → Fase 1 (3-4h) → Fase 2 (2-3h) → Fase 3 (2h)
→ Fase 4.1-4.3 (3h) → Fase 4.4-4.5 (3h) → Fase 4.6-4.9 (3h)
→ Fase 5 (4h) → Fase 6 (2h) → Fase 7 (1h)
```

**Estimativa total: 24-30 horas de desenvolvimento**

---

*Videira Dental Clinic — atualizar ao concluir cada tarefa.*
