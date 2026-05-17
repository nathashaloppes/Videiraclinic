# Videira Dental Clinic — ARQUITETURA.md

> Arquitetura definitiva do sistema VDC.
> Camadas, convenções e padrões de código de referência para toda a implementação.
> Última atualização: 2026-05-09

---

## 1. Visão geral

VDC é uma aplicação **Rails 7.2 fullstack monolítica** com Hotwire (Turbo + Stimulus). Não há SPA, não há API JSON pública, não há serviço externo de frontend. O navegador recebe HTML renderizado pelo Rails e a interatividade é incremental (Turbo Frames + Streams para áreas dinâmicas, Stimulus controllers para comportamento client-side).

Princípios:

1. **Convention over configuration.** Onde Rails define um padrão, segui-lo. Custom apenas quando justificado.
2. **Models magros / services finos / controllers RESTful.** Lógica de domínio no model. Orquestração de fluxos cross-model em services. Controllers só convertem HTTP em chamadas de domínio.
3. **Multi-tenant desde o MVP.** Toda query de domínio é escopada por `clinic_id` via `policy_scope`. Nada é "global".
4. **Auditoria por padrão.** Toda entidade que sofre mutação relevante tem `has_paper_trail`.
5. **Pessimistic locking onde houver disputa de recurso.** Concorrência em `Availability` é tratada com `lock!` + unique index defensivo.

---

## 2. Estrutura de pastas

```
videira_dental/
├── app/
│   ├── assets/
│   │   ├── stylesheets/
│   │   │   └── application.tailwind.css   ← @import Prompt + CSS vars + @tailwind
│   │   └── images/
│   │       └── logo.svg
│   ├── channels/
│   │   └── application_cable/
│   ├── controllers/
│   │   ├── application_controller.rb
│   │   ├── home_controller.rb
│   │   ├── cart_controller.rb
│   │   ├── booking_groups_controller.rb
│   │   ├── bookings_controller.rb
│   │   ├── payments_controller.rb
│   │   ├── users_controller.rb
│   │   ├── webhooks_controller.rb
│   │   ├── admin/
│   │   │   ├── base_controller.rb
│   │   │   ├── availabilities_controller.rb
│   │   │   ├── bookings_controller.rb
│   │   │   ├── discount_rules_controller.rb
│   │   │   └── users_controller.rb
│   │   └── users/
│   │       ├── omniauth_callbacks_controller.rb
│   │       ├── registrations_controller.rb
│   │       └── sessions_controller.rb
│   ├── helpers/
│   │   ├── application_helper.rb
│   │   ├── currency_helper.rb
│   │   └── date_helper.rb
│   ├── javascript/
│   │   ├── application.js
│   │   └── controllers/
│   │       ├── index.js
│   │       ├── countdown_controller.js
│   │       ├── clipboard_controller.js
│   │       ├── flash_controller.js
│   │       ├── modal_controller.js
│   │       ├── phone_mask_controller.js
│   │       ├── week_selector_controller.js
│   │       └── cart_controller.js
│   ├── jobs/
│   │   ├── application_job.rb
│   │   └── expire_payments_job.rb
│   ├── mailers/
│   │   └── application_mailer.rb            ← MVP sem mails transacionais (placeholder)
│   ├── models/
│   │   ├── application_record.rb
│   │   ├── concerns/
│   │   │   └── auditable.rb                 ← shortcut para has_paper_trail + meta
│   │   ├── clinic.rb
│   │   ├── user.rb
│   │   ├── room.rb
│   │   ├── availability.rb
│   │   ├── discount_rule.rb
│   │   ├── booking_group.rb
│   │   ├── booking.rb
│   │   └── payment.rb
│   ├── policies/
│   │   ├── application_policy.rb
│   │   ├── availability_policy.rb
│   │   ├── booking_policy.rb
│   │   ├── booking_group_policy.rb
│   │   ├── discount_rule_policy.rb
│   │   ├── payment_policy.rb
│   │   └── user_policy.rb
│   ├── services/
│   │   ├── application_service.rb           ← base com .call de classe
│   │   ├── discount_calculator.rb
│   │   ├── booking_group_creator.rb         ← orquestra create do BookingGroup
│   │   ├── booking_canceller.rb             ← regra 48h + atualizações
│   │   ├── mercado_pago/
│   │   │   ├── pix_creator.rb
│   │   │   ├── payment_finder.rb
│   │   │   └── webhook_validator.rb
│   │   └── payment_confirmer.rb             ← chamado pelo webhook
│   └── views/
│       ├── layouts/
│       │   ├── application.html.erb
│       │   └── admin.html.erb
│       ├── shared/
│       │   ├── _avatar.html.erb
│       │   ├── _back_button.html.erb
│       │   ├── _flash.html.erb
│       │   ├── _logo.html.erb
│       │   ├── _booking_cart.html.erb
│       │   ├── _slot_card.html.erb
│       │   ├── _week_selector.html.erb
│       │   └── _versions_table.html.erb
│       ├── home/
│       │   └── index.html.erb
│       ├── booking_groups/
│       │   ├── new.html.erb
│       │   └── show.html.erb
│       ├── bookings/
│       │   ├── index.html.erb
│       │   └── show.html.erb
│       ├── payments/
│       │   ├── show.html.erb
│       │   ├── _pending.html.erb
│       │   ├── _paid.html.erb
│       │   └── _expired.html.erb
│       ├── users/
│       │   └── show.html.erb
│       ├── devise/
│       │   ├── sessions/new.html.erb
│       │   ├── registrations/new.html.erb
│       │   ├── registrations/edit.html.erb
│       │   └── shared/_links.html.erb
│       ├── cart/
│       │   ├── _cart.html.erb
│       │   └── add.turbo_stream.erb
│       └── admin/
│           ├── availabilities/
│           ├── bookings/
│           ├── discount_rules/
│           └── users/
├── config/
│   ├── application.rb                        ← UUID default + tz America/Sao_Paulo
│   ├── routes.rb
│   ├── database.yml
│   ├── sidekiq.yml
│   ├── locales/pt-BR.yml
│   ├── importmap.rb
│   └── initializers/
│       ├── devise.rb
│       ├── pundit.rb
│       ├── pagy.rb
│       ├── paper_trail.rb
│       ├── sidekiq.rb
│       └── mercadopago.rb
├── db/
│   ├── migrate/
│   ├── schema.rb
│   └── seeds.rb
├── spec/  (ou test/)                         ← ver §10
├── lib/
│   └── tasks/
├── public/
├── tmp/
├── bin/
├── .env.example
├── .editorconfig
├── .rubocop.yml
├── Gemfile
├── Procfile                                  ← deploy
└── tailwind.config.js
```

> **Mudança em relação à estrutura sugerida no VSCODE_SETUP.md:** centralizei os partials compartilhados (`_slot_card`, `_week_selector`, `_booking_cart`) em `app/views/shared/` em vez de espalhá-los. Isso simplifica o `render` (`render 'shared/slot_card'`) e evita duplicação entre Home e Admin que usam o mesmo `WeekSelector`.

---

## 3. Camadas da aplicação

### 3.1 Models (`app/models`)

**Responsabilidade:** dados, validações, associações, scopes, transições de estado **atômicas e auto-suficientes** (`confirm!`, `expire!`, `cancel!`).

Regras:

- 1 arquivo por entidade. Sem god-objects.
- Métodos de classe são **factories** ou **finders** (`User.from_omniauth`, `DiscountRule.best_for`).
- Métodos de instância com `!` levantam exceção em falha; sem `!` retornam booleano ou nil.
- Toda transição que toca múltiplas tabelas vive dentro de `transaction do … end` no próprio model.
- Sem callbacks `after_save`/`after_create` que causam side-effects externos (jobs, mails, broadcasts). Esses ficam no service que chamou o save.
- Concerns só para comportamento **realmente** compartilhado (`Auditable` para `has_paper_trail` + meta). Nada de "trash dump" em concerns.

### 3.2 Services (`app/services`)

**Responsabilidade:** orquestrar fluxos que cruzam múltiplos models, ou que envolvem I/O externo (MercadoPago).

Regras:

- Toda service herda de `ApplicationService`, que oferece `self.call(*args, **kwargs) = new(*args, **kwargs).call`.
- Retorna `Result` simples: `OpenStruct.new(success?: true/false, value:, error:)` ou hash. Sem framework de monads.
- Nunca acessa `current_user` diretamente — recebe-o como argumento.
- Idempotência onde possível (importante para `PaymentConfirmer` chamado pelo webhook).
- Subnamespaces para integrações: `MercadoPago::PixCreator`, `MercadoPago::WebhookValidator`.

```ruby
# app/services/application_service.rb
class ApplicationService
  def self.call(...) = new(...).call
end
```

### 3.3 Jobs (`app/jobs`)

**Responsabilidade:** trabalho assíncrono via Sidekiq.

Regras:

- Herdam de `ApplicationJob`. `queue_as :default` salvo exceções.
- Idempotentes — podem ser re-executados sem efeitos colaterais.
- Sem lógica de domínio: o job carrega registros e delega para um service ou método de model.
- Recorrentes (cron) ficam declarados em `config/sidekiq.yml` via `sidekiq-cron` (a adicionar) ou `sidekiq-scheduler`.

### 3.4 Controllers (`app/controllers`)

**Responsabilidade:** parsing de params, autorização (Pundit), invocação de service/model, escolha de view/redirect.

Regras:

- 1 controller por recurso, RESTful (`index/show/new/create/edit/update/destroy`). Actions custom (`cancel`) só quando o recurso não cabe em CRUD puro.
- `before_action` para set de recurso e autenticação. Nada de queries inline na action.
- `private` no rodapé com `set_*` e `*_params`.
- Controllers admin sempre dentro de `Admin::` namespace e herdam de `Admin::BaseController`.
- Webhooks vivem em `WebhooksController`, com `skip_before_action :authenticate_user!` e `:verify_authenticity_token` somente nas actions necessárias.
- Sempre que um redirect retornar de uma action de mutação, usar `notice` para sucesso e `alert` para erro.

### 3.5 Views, layouts e partials (`app/views`)

**Responsabilidade:** HTML semântico mínimo, ERB com Rails helpers, classes Tailwind.

Regras:

- 2 layouts: `application.html.erb` (público + dentista) e `admin.html.erb` (sidebar + grid de navegação).
- Partials começam com `_` e ficam em `app/views/shared/` quando usados por mais de um controller.
- Cada Turbo Frame tem um `id` previsível (`"slot_#{availability.id}"`, `"cart"`, `"payment_status"`).
- Cada Turbo Stream broadcast tem um nome de canal previsível (`"payment_#{payment.id}"`).
- Nada de inline `<style>` ou `<script>` em ERB. Comportamento via Stimulus.
- Helpers de formatação ficam em `app/helpers/` (`brl(amount)`, `dia_semana(date)`).

### 3.6 Stimulus Controllers (`app/javascript/controllers`)

**Responsabilidade:** comportamento client-side incremental.

Regras:

- Um controller por arquivo, nome em snake_case com sufixo `_controller.js`.
- Métodos públicos são as actions referenciadas em `data-action`. Métodos privados começam com `_`.
- `static targets`, `static values`, `static classes` declarados explicitamente.
- Sem fetch direto — usar Turbo (`<form data-turbo-frame>`) sempre que possível.
- `connect()` configura, `disconnect()` faz cleanup (importantíssimo para timers/intervals).

### 3.7 Policies (`app/policies`)

**Responsabilidade:** regras de autorização por role e por escopo de tenant.

Regras:

- 1 policy por model. Métodos com `?` (`index?`, `show?`, `update?`, `cancel?`).
- `Scope` interna sempre filtra por `clinic_id`.
- Policies de admin são as **mesmas** policies do recurso — admin é um role, não um namespace separado de autorização. O namespace `Admin::` é só de roteamento/controllers/views.
- `verify_authorized` e `verify_policy_scoped` ativos no `ApplicationController`. Actions que pulam autorização (cart, webhook) usam `after_action :skip_authorization`.

---

## 4. Convenções de código

### 4.1 Ruby style

- Indentação: 2 espaços, sem tabs.
- Aspas duplas por padrão (consistente com Rails); aspas simples apenas em strings sem interpolação dentro de blocos longos onde a economia ajude leitura.
- `frozen_string_literal: true` **opcional** (RuboCop desabilitado para isso — vide §11).
- Métodos curtos preferidos (até 20 linhas — limite RuboCop relaxado).
- Endless method (`def x = …`) permitido para getters/predicados de uma linha. Métodos com lógica usam `def…end`.
- Hash literals no estilo `{ key: value }`. Símbolos sempre que a chave for fixa.
- `unless` apenas para condição simples. Nunca `unless…else`.
- Guard clauses preferidas a `if` aninhado.
- Comentários **somente** quando o "porquê" não é óbvio. Nada de comentar o "o quê".

### 4.2 Naming

- Models: `PascalCase` singular (`BookingGroup`).
- Tabelas: `snake_case` plural (`booking_groups`).
- FKs: `<singular>_id` (`booking_group_id`). Para self/aliased: `<role>_id` (`created_by_id`).
- Enums: símbolos em `snake_case`, valores `integer` indexados a partir de 0 (`{ pending: 0, confirmed: 1, … }`). **Nunca** alterar a ordem após o deploy.
- Services: substantivo + sufixo de ação (`DiscountCalculator`, `BookingGroupCreator`, `PaymentConfirmer`).
- Jobs: substantivo + `Job` (`ExpirePaymentsJob`).
- Stimulus controllers: nome em kebab-case na referência HTML (`data-controller="phone-mask"`), arquivo `phone_mask_controller.js`.
- Routes: paths em **português** (`/conta`, `/minhas-reservas`, `/admin/disponibilidade`); helpers seguem o `as:` (snake_case) ou o nome do recurso.
- I18n keys: estrutura `pt-BR.activerecord.attributes.<model>.<attr>` para tradução automática de erros.

### 4.3 ERB style

- Atributos HTML em ordem: `id`, `class`, `data-*`, demais.
- Nada de `<%= raw … %>` ou `html_safe` salvo em conteúdo controlado.
- Em vez de `style="background-color: #5D4037"`, usar **Tailwind utility com cor do tema** (`bg-primary`). Estilos inline só quando o valor é dinâmico vindo do banco.
- Locais explícitos no `render`: `render 'shared/avatar', user: @user, size: :md`. Sem `:object` mágico.
- Turbo Frames sempre com `id` semântico e fallback de conteúdo (não deixar frame vazio quando JS desabilitado).

### 4.4 Stimulus conventions

- Ler `static values` em vez de `data-*` brutos no controller.
- Toda emissão custom usa `this.dispatch("eventName", { detail })` para que outros controllers possam ouvir.
- Estado local → `static values`. Estado global compartilhado entre frames → preferir Turbo Stream do server.

### 4.5 Tailwind conventions

- Cores definidas em `tailwind.config.js` (`primary`, `secondary`, `accent`, `background`, `foreground`, `pix`, `success`, `destructive`).
- Classes sempre na ordem: layout → flexbox/grid → espaçamento → tipografia → cores → estado.
- Componentes recorrentes (botão primário, card branco) viram **partial**, não classe utilitária CSS.

### 4.6 Migrations

- Sempre `null: false` em colunas obrigatórias.
- Sempre `default:` em flags booleanas.
- `precision`/`scale` explícitos em `decimal`.
- Foreign keys com `foreign_key: true` (cria constraint no Postgres).
- Índices justificados no nome ou em comentário acima da migration.
- Uma única responsabilidade por migration. Nunca misturar criação de tabela com seed/data fix.

### 4.7 Erros e mensagens

- Mensagens de UI sempre em **pt-BR**.
- Erros de domínio levantados com mensagem direta para o usuário (`raise "Cancelamento não permitido: faltam menos de 48h."`). Controller faz rescue e converte em flash.
- Erros internos (5xx, MercadoPago indisponível) loggados com `Rails.logger.error` e mostrados como mensagem genérica ("Tivemos um problema. Tente novamente.").

---

## 5. Comunicação entre camadas

```
HTTP request
    ↓
Routes → Controller (Pundit authorize, params permit)
    ↓                                ↓
    │                                ↓ (fluxo cross-model ou I/O externo)
    │                              Service
    ↓                                ↓
   Model.<query|state-method>  ←── Model
    ↓                                ↓
   ActiveRecord ←──────────────── ActiveRecord
    ↓
Database
```

### 5.1 Quando usar service vs método de model

**Use service quando:**
- O fluxo cruza 3+ models (`BookingGroupCreator` toca BookingGroup, Booking, Availability, Payment).
- Há I/O externo (MercadoPago HTTP, envio de mail, broadcast Turbo Stream).
- Há lógica de negócio que não pertence "a" nenhum model em particular (`DiscountCalculator`).

**Use método de model quando:**
- A operação muda apenas o próprio registro e seus filhos diretos (`BookingGroup#confirm!` muda BookingGroup + seus Bookings + seu Payment).
- A regra é uma propriedade do registro (`Availability#cancellable?`).

### 5.2 Webhook → service → model

```
WebhooksController#mercadopago
    ↓ valida assinatura via MercadoPago::WebhookValidator
    ↓ extrai provider_payment_id
    ↓ busca dados via MercadoPago::PaymentFinder
    ↓
PaymentConfirmer.call(provider_payment_id, status: "approved")
    ↓ idempotente (no-op se já paid)
    ↓ encontra BookingGroup pelo external_reference
    ↓
BookingGroup#confirm!  (transação, atualiza bookings + payment)
    ↓
Turbo::StreamsChannel.broadcast_replace_to("payment_#{id}", …)
```

### 5.3 Cart → BookingGroup

```
Anonymous user → CartController#add → session[:cart_ids] += id
                                              ↓
                                     Turbo Stream replace _cart partial
Login obrigatório antes do checkout
                                              ↓
BookingGroupsController#new → exibe resumo (DiscountCalculator.call)
                                              ↓
BookingGroupsController#create → BookingGroupCreator.call
                                              ↓
                              transaction:
                                lock! availabilities (SELECT FOR UPDATE)
                                re-valida booked: false
                                cria BookingGroup (status: pending)
                                cria N Bookings (status: pending)
                                marca availability.booked = true (hold)
                                MercadoPago::PixCreator.call → cria Payment
                              clear session[:cart_ids]
                                              ↓
                              redirect_to payment_path(@payment)
```

---

## 6. Routes (definitivas)

```ruby
Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    registrations:      'users/registrations',
    sessions:           'users/sessions'
  }, path_names: {
    sign_in:  'login',
    sign_out: 'logout',
    sign_up:  'cadastro'
  }

  # Webhook MercadoPago — sem CSRF, sem auth
  post '/webhooks/mercadopago', to: 'webhooks#mercadopago'

  root 'home#index'

  # Carrinho de slots (session-based, anônimo permitido)
  post   '/carrinho/adicionar', to: 'cart#add',    as: :cart_add
  delete '/carrinho/remover',   to: 'cart#remove', as: :cart_remove
  delete '/carrinho/limpar',    to: 'cart#clear',  as: :cart_clear

  # Dentista autenticada
  get   '/conta',           to: 'users#show',     as: :conta
  patch '/conta',           to: 'users#update'
  get   '/minhas-reservas', to: 'bookings#index', as: :bookings

  resources :booking_groups, only: %i[new create show], path: 'reservas',
            path_names: { new: 'confirmar' }
  resources :payments, only: %i[show], path: 'pagamento'
  resources :bookings, only: %i[show] do
    member { patch :cancel }
  end

  namespace :admin do
    get '/', to: redirect('/admin/reservas')
    resources :availabilities, path: 'disponibilidade', except: %i[show]
    resources :bookings,       path: 'reservas',        only: %i[index show update]
    resources :users,          path: 'clientes',        only: %i[index show update]
    resources :discount_rules, path: 'descontos',       except: %i[show]
  end

  get '/up', to: proc { [200, {}, ['ok']] }
end
```

> **Mudanças em relação ao `routes.rb` original:**
> - `cart` muda de `POST /cart/...` (3 POSTs) para verbos REST corretos: `add` (POST), `remove` (DELETE), `clear` (DELETE).
> - Path em pt-BR: `carrinho` em vez de `cart`.
> - `payments` ganha `path: 'pagamento'` (singular pt-BR, consistente com a tela `/pagamento/:id` do CONTEXT).
> - `booking_groups` ganha `path_names: { new: 'confirmar' }` para que `new_booking_group_path` resolva como `/reservas/confirmar` (match com a rota documentada no CONTEXT seção 10).

---

## 7. Layouts

### 7.1 `application.html.erb` (público + dentista)

- Fundo `#fef8e1`, fonte Prompt.
- Container `max-w-md mx-auto px-4 py-6`.
- `<header>` condicional: logo central + (avatar/login) + (carrinho se tiver itens).
- `<%= yield %>` no main.
- Turbo Frame `#cart` permanente para que adições do carrinho sobrevivam navegação.
- `<%= render 'shared/flash' %>` no topo do main.

### 7.2 `admin.html.erb` (owner)

- Mesmo wrapper visual do `application` (consistência visual).
- Header com logo central + botão logout à direita.
- Grid 2x2 de navegação (`Reservas`, `Clientes`, `Disponibilidade`, `Descontos`).
- `<%= yield %>` abaixo da grid.
- Sem carrinho (owner não compra).

---

## 8. Concorrência e estados

### 8.1 Disputa de slot

A unique index em `bookings.availability_id` é a defesa **canônica** contra double-booking. O fluxo do `BookingGroupCreator`:

```ruby
ActiveRecord::Base.transaction do
  availabilities = Availability.where(id: cart_ids).lock!     # SELECT FOR UPDATE
  raise BookingGroupCreator::SlotTaken if availabilities.any?(&:booked?)

  group = BookingGroup.create!(...)
  availabilities.each do |av|
    Booking.create!(booking_group: group, availability: av, user:, status: :pending)
    av.update!(booked: true)
  end
  Payment.create!(...)   # depois de criar o pix via MercadoPago
end
```

`SlotTaken` é capturado no controller e vira flash explicativo + redirect.

### 8.2 Webhook duplicado

`PaymentConfirmer` é idempotente:

```ruby
return if booking_group.confirmed?
booking_group.confirm!
```

### 8.3 Job de expiração

`ExpirePaymentsJob` busca `Payment.expiring` (`pending` + `expires_at < now`) e expira o `BookingGroup`. Race com webhook resolvida pelo idempotente: se `confirm!` já rodou (status `confirmed`), `expire!` não muda nada útil, mas para evitar inconsistência, `expire!` também valida:

```ruby
def expire!
  return unless pending?
  transaction { … }
end
```

---

## 9. I18n

- Locale default: `pt-BR`.
- `config.time_zone = 'America/Sao_Paulo'`.
- Arquivo `config/locales/pt-BR.yml` com:
  - `activerecord.models.*` (nomes singular/plural)
  - `activerecord.attributes.*` (todos os campos visíveis na UI)
  - `errors.messages.*` (mensagens custom)
  - `helpers.submit.*` (textos de botões "Criar/Atualizar/Destruir")
- Datas: helper `dia_semana(date)` retorna "Quarta-feira, 14 de Maio".
- Moeda: helper `brl(amount) → "R$ 150,00"`.

---

## 10. Testes

> **Decisão:** apesar de `--skip-test` no `rails new`, **adicionar RSpec** depois (`gem 'rspec-rails'`). O setup de migrations + autorização + transições de estado é complexo demais para confiar em "testar manualmente". Custo de adicionar = ~1h, ganho = regressão automática para sempre.

Estrutura mínima:

```
spec/
├── rails_helper.rb
├── spec_helper.rb
├── factories/                ← FactoryBot
├── models/
│   ├── availability_spec.rb  ← cancellable?, validations
│   ├── booking_spec.rb       ← cancel!, confirm!
│   ├── booking_group_spec.rb ← confirm!, expire!
│   └── discount_rule_spec.rb ← best_for
├── services/
│   ├── discount_calculator_spec.rb
│   ├── booking_group_creator_spec.rb
│   └── payment_confirmer_spec.rb
├── policies/
└── system/                   ← happy-path: criar reserva, cancelar
    ├── booking_flow_spec.rb
    └── payment_flow_spec.rb
```

Cobertura mínima exigida antes do deploy: services + transições de estado dos models.

---

## 11. Linting e formatação

`.rubocop.yml`:

```yaml
AllCops:
  NewCops: enable
  TargetRubyVersion: 3.3
  Exclude:
    - 'db/schema.rb'
    - 'db/migrate/*'
    - 'bin/**/*'
    - 'vendor/**/*'
    - 'node_modules/**/*'
    - 'config/initializers/devise.rb'

Layout/LineLength:
  Max: 120

Metrics/MethodLength:
  Max: 20

Metrics/AbcSize:
  Max: 25

Style/Documentation:
  Enabled: false

Style/FrozenStringLiteralComment:
  Enabled: false

Style/HashSyntax:
  EnforcedShorthandSyntax: either   # permite { user: } e { user: user }
```

Pré-commit (opcional): `gem 'lefthook'` ou `overcommit` para rodar `rubocop` + testes rápidos.

---

## 12. Variáveis de ambiente (definitivas)

```bash
# Banco
DATABASE_URL=postgresql://localhost/videira_dental_development

# MercadoPago
MERCADOPAGO_ACCESS_TOKEN=TEST-xxxx
MERCADOPAGO_PUBLIC_KEY=TEST-xxxx
MERCADOPAGO_WEBHOOK_SECRET=xxxx           # OBRIGATÓRIO — usado em WebhookValidator

# Google OAuth
GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=xxxx

# App
APP_HOST=http://localhost:3000
APP_DEFAULT_TIMEZONE=America/Sao_Paulo
RAILS_ENV=development
SECRET_KEY_BASE=                          # gerado via `rails secret`

# Pagamento — janela em minutos (default 30)
PAYMENT_EXPIRATION_MINUTES=30

# Cancelamento — antecedência em horas (default 48)
CANCELLATION_LEAD_HOURS=48
```

> **Mudança em relação ao `.env.example` original:** adicionar `PAYMENT_EXPIRATION_MINUTES` e `CANCELLATION_LEAD_HOURS` como vars de ambiente para que a regra de negócio não precise de deploy de código quando a dona quiser ajustar. Default mantém o documentado (30/48).

---

*Arquitetura validada — base canônica para o ROADMAP_TECNICO.md.*
