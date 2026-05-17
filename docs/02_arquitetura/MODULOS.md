# Videira Dental Clinic — MODULOS.md

> Mapa funcional do sistema dividido em 5 módulos.
> Cada módulo: o que faz, arquivos, dependências, edge cases críticos.
> Última atualização: 2026-05-09

---

## Visão geral

| Módulo | Responsabilidade | Principal entrega ao usuário |
|---|---|---|
| **Auth** | Identidade, sessão, permissões | Dentista loga, owner administra |
| **Scheduling** | Catálogo de slots, carrinho, criação de reservas, cancelamento | Dentista escolhe e agenda; owner gerencia disponibilidade |
| **Payments** | QR Code Pix, webhook, expiração | Dentista paga; sistema confirma reserva |
| **Admin** | Painel da owner: reservas, clientes, descontos | Owner controla o negócio |
| **Audit** | PaperTrail: histórico de tudo | Owner audita alterações |

---

## 1. Auth

### 1.1 O que faz

- Cadastro de **dentista** (auto-registro: email/senha ou Google OAuth).
- Cadastro de **owner** apenas via seeds/console (não há UI pública).
- Login, logout, recuperação de senha.
- Multi-tenant: associa todo usuário a uma `Clinic` no momento do cadastro.
- Define o role (`owner` | `dentist`) que rege todas as autorizações.
- Expõe `current_user` para Pundit, PaperTrail e o resto da aplicação.

### 1.2 Arquivos

```
app/models/
  user.rb                                 ← Devise + roles + has_paper_trail + has_one_attached :avatar
  clinic.rb                               ← tenant root

app/controllers/
  application_controller.rb               ← authenticate_user!, set_paper_trail_whodunnit, Pundit
  users/
    omniauth_callbacks_controller.rb      ← Google OAuth → User.from_omniauth
    registrations_controller.rb           ← extends Devise; permite name/phone/cro/specialty
    sessions_controller.rb                ← extends Devise (placeholder)

app/policies/
  user_policy.rb                          ← show?/update? por role + ownership

app/views/devise/
  sessions/new.html.erb                   ← tela Login (Figma)
  registrations/new.html.erb              ← tela Cadastro (Figma)
  registrations/edit.html.erb             ← perfil próprio (próximo MVP)
  passwords/new.html.erb                  ← reset de senha
  shared/_links.html.erb

config/
  initializers/devise.rb                  ← OmniAuth google_oauth2
  routes.rb                               ← devise_for :users path_names: { login, cadastro, logout }
```

### 1.3 Dependências

- **Externas (gems):** `devise`, `omniauth-google-oauth2`, `omniauth-rails_csrf_protection`, `pundit`, `paper_trail`.
- **Internas (módulos):** Audit (todo update de User gera Version).
- **Externas (serviços):** Google Cloud — OAuth client (configurado fora do código).

### 1.4 Decisões importantes

- `email` **não pode** ser alterado pelo owner. Para a dentista alterar o próprio email, usa o fluxo Devise padrão (`registrations#edit`) — fluxo será habilitado em fase 2.
- `clinic_id` no User é `null: false`. No MVP, todo cadastro vai para `Clinic.first`. Quando expandir para multi-tenant, o cadastro deverá receber slug da clínica via URL ou subdomínio.
- Role default = `:dentist`. Owner é criado **apenas** via seeds.
- Avatar via ActiveStorage (`has_one_attached :avatar`). Sem URL externa em coluna.

### 1.5 Edge cases críticos

| Caso | O que pode quebrar | Como tratar |
|---|---|---|
| Usuário se cadastra com email já cadastrado via OAuth | Devise rejeita por email único | Fallback: redireciona para login com mensagem "Use o Google para entrar" |
| OAuth retorna sem `email` (raro, conta sem email público) | `User.from_omniauth` falha | Validar `auth.info.email.present?` antes de `first_or_create`; erro amigável |
| Owner é criado sem clínica | Constraint `null: false` viola | Seeds cria clínica primeiro, owner depois |
| Dentista tenta acessar `/admin/...` | Pundit nega | `Admin::BaseController#require_owner!` redireciona com flash |
| Usuário sem `cro_number` salva como dentist | Validação `presence: true, if: :dentist?` rejeita | OK |
| Logout via GET acidental | Devise por padrão exige DELETE | Mantém `sign_out_via :delete` + `button_to method: :delete` |
| Sessão expirada durante checkout | `BookingGroupsController` redireciona para login | Salvar cart na sessão **antes** de exigir login |

### 1.6 Pontos de extensão futuros

- Confirmação de email (Devise `:confirmable`) — desabilitado no MVP para acelerar onboarding.
- Login com microsoft/apple — adicionar provider em devise.rb.
- 2FA — `devise-two-factor` quando houver volume.

---

## 2. Scheduling

### 2.1 O que faz

- **Owner:** CRUD de `Availability` (slots).
- **Dentista:** vê slots disponíveis, adiciona ao carrinho (sessão), faz checkout criando `BookingGroup` + `Booking`s.
- **Dentista:** cancela `Booking` individual respeitando regra de **48h de antecedência**.
- **Sistema:** marca `Availability#booked` ao criar booking pendente (hold), libera ao expirar/cancelar.

### 2.2 Arquivos

```
app/models/
  availability.rb                         ← scopes available/for_date/for_clinic/upcoming + cancellable?
  booking.rb                              ← cancel!(reason), confirm!, cancel_expired!
  booking_group.rb                        ← confirm!, expire!, has_many :bookings
  discount_rule.rb                        ← best_for(quantity, clinic)

app/services/
  application_service.rb                  ← base
  discount_calculator.rb                  ← calcula subtotal, regra, desconto, total
  booking_group_creator.rb                ← orquestra: lock! avail. + cria group + bookings + payment
  booking_canceller.rb                    ← regra 48h + atualiza booking + libera slot + (talvez) cancela group

app/controllers/
  home_controller.rb                      ← lista de slots por data (público)
  cart_controller.rb                      ← session[:cart_ids] add/remove/clear
  booking_groups_controller.rb            ← new (resumo) / create / show
  bookings_controller.rb                  ← index (minhas reservas), show, cancel

app/policies/
  availability_policy.rb
  booking_policy.rb
  booking_group_policy.rb

app/javascript/controllers/
  cart_controller.js                      ← UI do carrinho (toggle, badges)
  week_selector_controller.js             ← navegação semanal sem reload

app/views/
  home/index.html.erb
  shared/_slot_card.html.erb
  shared/_week_selector.html.erb
  shared/_booking_cart.html.erb
  cart/add.turbo_stream.erb
  cart/remove.turbo_stream.erb
  cart/clear.turbo_stream.erb
  booking_groups/new.html.erb
  booking_groups/show.html.erb
  bookings/index.html.erb
  bookings/show.html.erb
```

### 2.3 Dependências

- **Externas (gems):** `pagy`, `pundit`, `paper_trail`.
- **Internas:** Auth (precisa de `current_user` no checkout), Payments (chamado pelo `BookingGroupCreator`), Audit.
- **Externas (serviços):** nenhum direto. Pix é responsabilidade do módulo Payments.

### 2.4 Fluxos completos

**Criar slot (owner):**

```
GET /admin/disponibilidade?date=2026-05-15
  → Admin::AvailabilitiesController#index
  → policy_scope(Availability).for_date(...).order(:starts_at)

POST /admin/disponibilidade  { date, starts_at, ends_at, price }
  → Admin::AvailabilitiesController#create
  → Availability.new(... room: clinic.room, created_by: current_user)
  → save! (validações: date, starts_at, ends_at, price > 0, ends_at > starts_at)
  → PaperTrail registra Version event=create
```

**Reservar (dentista):**

```
1. Anônima ou logada navega Home → adiciona slots ao carrinho via Stimulus
   POST /carrinho/adicionar { availability_id }
   → CartController#add → session[:cart_ids] << id
   → render add.turbo_stream.erb (replace #cart partial)

2. Click "Pagar com Pix" exige login (se anônima, redirect para /login com return_to)

3. GET /reservas/confirmar
   → BookingGroupsController#new
   → DiscountCalculator.call(session[:cart_ids], clinic)
   → renderiza resumo + total

4. POST /reservas (botão "Confirmar e pagar")
   → BookingGroupsController#create
   → BookingGroupCreator.call(user: current_user, availability_ids: session[:cart_ids])
       → transaction:
           availabilities = Availability.where(id: ids).lock!
           validar todas booked: false
           BookingGroup.create!(subtotal, total, ...)
           availabilities.each → Booking.create!, av.update!(booked: true)
           pix = MercadoPago::PixCreator.call(group)
           Payment.create!(...)
       → return Result(success: true, value: group)
   → session.delete(:cart_ids)
   → redirect_to payment_path(group.payment)
```

**Cancelar (dentista):**

```
PATCH /bookings/:id/cancel  { cancel_reason }
  → BookingsController#cancel
  → authorize @booking, :cancel?  (somente dona, somente confirmed)
  → cancel_reason presente?
  → BookingCanceller.call(booking: @booking, reason:)
      → raise se !availability.cancellable? (48h)
      → transaction:
          booking.update!(status: :cancelled, cancelled_at: now, cancel_reason: reason)
          booking.availability.update!(booked: false)
          se todos os bookings do group estão cancelled → group.update!(status: :cancelled)
  → redirect_to bookings_path com notice/alert
```

### 2.5 Edge cases críticos

| Caso | O que pode quebrar | Como tratar |
|---|---|---|
| Duas dentistas selecionam o mesmo slot e clicam "Pagar com Pix" simultaneamente | Double-booking | `lock!` na transação + unique index `bookings.availability_id` (segunda transação levanta `RecordNotUnique`) → controller captura e mostra "Slot indisponível" |
| Dentista adiciona slot ao carrinho, espera 1h, slot foi reservado por outra | `BookingGroupCreator` levanta `SlotTaken` | Service captura, retorna `Result(success: false)`, controller redireciona ao Home com mensagem |
| `cancel_reason` em branco | `BookingCanceller` recebe string vazia | Controller já valida antes; service tem `validates :cancel_reason, presence: true, if: :cancelled?` |
| Cancela 47:59h antes | `Availability#cancellable?` retorna false | Service levanta erro com mensagem legível |
| Cancelar booking de grupo já expirado | Status já é `cancelled` | `cancel!` é no-op se status != confirmed (Pundit `cancel?` exige `confirmed?`) |
| Dentista cria booking_group com cart vazio | Lista vazia, divisão por zero em desconto | Controller redireciona para `/` com alert "Selecione ao menos um horário" |
| Cart com IDs que não existem mais (slot deletado) | `Availability.where(id: [...])` retorna menos do que solicitado | Service compara `availabilities.count != ids.length` → erro |
| Slot tem `ends_at < starts_at` | Validação Ruby + check Postgres | Bloqueado em duas camadas |
| Owner deleta slot reservado | `destroy` rejeita se `booked?` | Controller já trata; backup: poderia haver `restrict_with_error :booking` |
| Race com job de expiração: dentista paga no segundo 29:59 | Webhook chega depois do job | `confirm!` e `expire!` ambos checam `pending?` antes de mudar; se `expired` chegou primeiro, `confirm!` ignora silenciosamente. **Decisão de produto:** se isso acontecer, criar issue e tratar manualmente (refund + reagendamento) |

### 2.6 Convenções específicas do módulo

- **Sempre** `for_clinic(user.clinic)` no scope. Nunca `Availability.all`.
- Fuso horário: `Time.zone.parse` ou `Date.current` (nunca `Time.now` ou `Date.today`).
- `cart_ids` na session: array de strings UUID.
- Carrinho de anônimos persiste enquanto durar a sessão. Em login, **não merge** com cart de logado (cada sessão é isolada).

---

## 3. Payments

### 3.1 O que faz

- Cria `Payment` Pix via MercadoPago para cada `BookingGroup`.
- Recebe webhook do MercadoPago e confirma o pagamento.
- Expira `Payment`s não pagos via Sidekiq (job recorrente a cada 5 min).
- Faz broadcast Turbo Stream para a tela de pagamento atualizar quando o status mudar.

### 3.2 Arquivos

```
app/models/
  payment.rb                              ← enum status, scope :expiring, seconds_remaining

app/services/
  mercado_pago/
    pix_creator.rb                        ← chama SDK, cria preference, devolve { provider_id, pix_code, pix_qr_url }
    payment_finder.rb                     ← lookup pelo provider_id
    webhook_validator.rb                  ← valida assinatura HMAC do MP
  payment_confirmer.rb                    ← idempotente; chama BookingGroup#confirm! + broadcast

app/controllers/
  payments_controller.rb                  ← #show
  webhooks_controller.rb                  ← #mercadopago (skip CSRF)

app/policies/
  payment_policy.rb

app/jobs/
  expire_payments_job.rb                  ← Payment.expiring → BookingGroup#expire!

app/javascript/controllers/
  countdown_controller.js                 ← timer regressivo no card de pagamento
  clipboard_controller.js                 ← copiar pix_code

app/views/
  payments/
    show.html.erb                         ← turbo_stream_from "payment_#{id}" + frame status
    _pending.html.erb                     ← QR + countdown + copia/cola
    _paid.html.erb                        ← confirmação verde
    _expired.html.erb                     ← mensagem "Pagamento expirado"

config/initializers/
  mercadopago.rb                          ← sanity check que ENV está presente
  sidekiq.rb                              ← Redis URL
config/sidekiq.yml                        ← schedule recorrente do ExpirePaymentsJob
```

### 3.3 Dependências

- **Externas (gems):** `mercadopago`, `sidekiq`, `redis`.
- **Internas:** Scheduling (`BookingGroup` é o "agregado raiz" do Pix), Audit.
- **Externas (serviços):** **MercadoPago API** (criação de preference + webhook).

### 3.4 Fluxos

**Criar Pix (chamado pelo BookingGroupCreator):**

```ruby
result = MercadoPago::PixCreator.call(booking_group)
# result => { provider_id:, pix_code:, pix_qr_url:, expires_at: }
Payment.create!(
  booking_group: group,
  provider:      'mercadopago',
  provider_id:   result[:provider_id],
  pix_code:      result[:pix_code],
  pix_qr_url:    result[:pix_qr_url],
  amount:        group.total,
  expires_at:    result[:expires_at],
  status:        :pending
)
```

**Webhook (MercadoPago notifica):**

```
POST /webhooks/mercadopago  (sem CSRF, sem auth)
  body: { type: "payment", action: "payment.updated", data: { id: "PROVIDER_ID" } }
  headers: x-signature: t=…, v1=… ;  x-request-id: …

WebhooksController#mercadopago
  → MercadoPago::WebhookValidator.call(request)
      → valida HMAC contra ENV[MERCADOPAGO_WEBHOOK_SECRET]
      → 401 se inválido
  → parse JSON
  → mp_data = MercadoPago::PaymentFinder.call(payload.dig("data","id"))
  → return head :ok se mp_data nil ou status != approved (idempotente)
  → PaymentConfirmer.call(external_reference: mp_data["external_reference"])
      → group = BookingGroup.find_by(id: external_reference)
      → return if group.nil? || group.confirmed?
      → group.confirm!
      → Turbo::StreamsChannel.broadcast_replace_to(
            "payment_#{group.payment.id}",
            target:  "payment_status",
            partial: "payments/paid",
            locals:  { payment: group.payment }
          )
  → head :ok (sempre — para não fazer MP retentar)
```

**Expiração (Sidekiq):**

```ruby
# config/sidekiq.yml (com sidekiq-cron ou schedule)
:schedule:
  expire_payments:
    cron: "*/5 * * * *"           # a cada 5 min
    class: ExpirePaymentsJob

# app/jobs/expire_payments_job.rb
def perform
  Payment.expiring.includes(:booking_group).find_each do |payment|
    next if payment.booking_group.confirmed?
    payment.booking_group.expire!
    Turbo::StreamsChannel.broadcast_replace_to(
      "payment_#{payment.id}",
      target:  "payment_status",
      partial: "payments/expired",
      locals:  { payment: payment.reload }
    )
  end
end
```

### 3.5 Edge cases críticos

| Caso | O que pode quebrar | Como tratar |
|---|---|---|
| Webhook chega antes do `Payment` ser persistido (race no checkout) | `find_by(external_reference)` retorna nil | `PaymentConfirmer` retorna no-op; MP retenta automaticamente |
| Webhook duplicado (MP retenta ou rede) | `confirm!` já rodou | `return if group.confirmed?` torna idempotente |
| Webhook com assinatura inválida | Ataque ou bug | `WebhookValidator` retorna falso → controller responde 401 e loga |
| MP fora do ar no momento de criar Pix | `PixCreator` recebe erro HTTP | Service retorna `Result(success: false)`; `BookingGroupCreator` faz `raise ActiveRecord::Rollback`; controller mostra "Tente novamente" |
| Job de expiração roda enquanto webhook está em transação | Lock + `pending?` check protegem | Pessimistic lock no `expire!` se necessário |
| Payment expira mas `Availability#booked` não foi liberado | `BookingGroup#expire!` chama `bookings.each(&:cancel_expired!)` que libera | OK; backup: scope `Availability.stale_holds` (booked: true sem booking ativo) para health check |
| `pix_qr_url` retorna vazio do MP (modo sandbox sem flow real) | Tela quebra | Fallback `"SANDBOX_PIX_<uuid>"` no service; UI mostra mensagem em sandbox |
| `expires_at` no Payment difere da `date_of_expiration` enviada ao MP | Inconsistência usuário vê 30 min, MP aceita 35 | `expires_at` salvo no banco = `Time.current + ENV.fetch('PAYMENT_EXPIRATION_MINUTES', 30).to_i.minutes`; mesmo valor passado ao MP |
| Dentista paga depois de `expires_at` mas MP processou | Cobrança feita, mas booking expirado | Webhook ainda chega, mas `BookingGroup` já está `:expired`. **Decisão crítica:** webhook deve **estornar** via MP API ou alertar admin. **MVP:** loga incident e envia email para `owner_email` para tratamento manual |

### 3.6 Convenções específicas do módulo

- Toda chamada à API MP é envolvida em `begin/rescue` com fallback de log.
- **Idempotência** é obrigatória em `PaymentConfirmer`. Não há "garantia" de que o webhook chega 1x.
- `ExpirePaymentsJob` é safe para rodar mais frequente do que 5 min (idempotente).
- **Nunca** confiar no `status` enviado pelo webhook; sempre re-buscar via `MercadoPago::PaymentFinder`.

---

## 4. Admin

### 4.1 O que faz

Painel exclusivo do `owner` para gerenciar:
- **Disponibilidade:** criar, editar, deletar slots.
- **Reservas:** ver todas, filtrar por data, editar status manualmente (caso de exceção).
- **Clientes (dentistas):** listar, buscar, ver detalhes (dados + reservas + histórico de alterações).
- **Descontos:** CRUD de `DiscountRule`.

### 4.2 Arquivos

```
app/controllers/admin/
  base_controller.rb                      ← require_owner!
  availabilities_controller.rb            ← CRUD
  bookings_controller.rb                  ← index/show/update
  users_controller.rb                     ← index (busca)/show (detalhes)/update (edita dados, NUNCA email)
  discount_rules_controller.rb            ← CRUD

app/views/admin/
  availabilities/
    index.html.erb                        ← seletor de semana + lista do dia + "Adicionar"
    new.html.erb                          ← modal-style page
    edit.html.erb
    _form.html.erb
  bookings/
    index.html.erb                        ← filtros, paginação
    show.html.erb                         ← com aba histórico (PaperTrail)
  users/
    index.html.erb                        ← busca + paginação
    show.html.erb                         ← abas: dados | reservas | histórico
    edit.html.erb                         ← form sem :email
  discount_rules/
    index.html.erb                        ← tabela
    new.html.erb
    edit.html.erb

app/views/layouts/
  admin.html.erb                          ← logo central + grid 2x2 + yield
```

### 4.3 Dependências

- **Externas (gems):** `pagy`, `pundit`, `paper_trail`.
- **Internas:** Auth (require_owner!), Scheduling (recursos editados), Audit (renderiza histórico).

### 4.4 Decisões importantes

- Admin é um **role**, não um sistema separado. Mesmas policies, mesmo schema, mesmos models.
- `email` da dentista **não é editável** pelo owner. `admin_user_params` não inclui `:email`.
- `birth_date` é editável pelo owner (consistente com CONTEXT 6.10).
- Filtro de busca em `Admin::UsersController#index`: `name ILIKE` ou `cro_number ILIKE` (case-insensitive Postgres).
- `Admin::BookingsController#update` permite mudar `status` manualmente — usado em casos de exceção (ex: cobrança fora do sistema). Toda mudança fica no PaperTrail.

### 4.5 Edge cases críticos

| Caso | O que pode quebrar | Como tratar |
|---|---|---|
| Owner tenta deletar slot reservado | Validação `if @availability.booked?` no controller bloqueia | Mensagem amigável; backup: FK constraint do Postgres impediria DELETE |
| Owner tenta editar email da dentista via params injection | `admin_user_params` não permite `:email` → ignorado silenciosamente | Strong params bloqueia. Não é necessário erro explícito (Rails default) |
| Busca com SQL injection (`'; DROP TABLE`) | `ILIKE ?` parametrizado | Bind via `?` blinda; sem string interpolation |
| Owner edita `discount_rule` ativa enquanto dentista está no checkout | Dentista pode ver desconto antigo, pagar com novo | **Decisão MVP:** no `BookingGroupCreator`, recalcular desconto **dentro da transação** com `DiscountRule.best_for` chamado no momento. Discount é "frozen" na criação do BookingGroup |
| Owner deleta `discount_rule` ainda referenciada por BookingGroup antigo | `discount_rules.id` é FK em `booking_groups`; sem `dependent:` | FK sem `on_delete: :cascade` → Postgres impede DELETE. **Decisão:** soft-delete via `active: false`. `Admin::DiscountRulesController#destroy` muda `active = false` em vez de `destroy_all`. **Atualizar implementação:** trocar `destroy` por update do flag |
| Dois owners da mesma clínica editam o mesmo slot simultaneamente | MVP tem 1 owner por clínica | Não é problema atual; `updated_at` optimistic locking se virar caso |
| Owner navega `/admin/clientes/:id` de dentista de outra clínica | `policy_scope(User)` filtra por clinic | Already covered |

### 4.6 Convenções específicas do módulo

- Toda action admin **autoriza** com `authorize` ou `policy_scope`.
- Views admin reutilizam partials de `shared/`.
- Nada de "links secretos" para sair do namespace `/admin`. Todas as rotas admin começam com `/admin`.

---

## 5. Audit

### 5.1 O que faz

- Registra **toda** alteração relevante via PaperTrail.
- Atribui o usuário responsável (`whodunnit = current_user.id`) automaticamente.
- Expõe interface (na tela de detalhes) para a owner consultar o histórico.

### 5.2 Arquivos

```
app/models/concerns/
  auditable.rb                            ← optional concern: extend para has_paper_trail + meta padrão

app/models/
  user.rb            has_paper_trail
  availability.rb    has_paper_trail
  discount_rule.rb   has_paper_trail
  booking.rb         has_paper_trail
  booking_group.rb   has_paper_trail
  payment.rb         has_paper_trail

app/controllers/
  application_controller.rb               ← before_action :set_paper_trail_whodunnit; user_for_paper_trail

app/views/shared/
  _versions_table.html.erb                ← renderiza versions ordenadas, com diff legível

app/helpers/
  versions_helper.rb                      ← format_change(version, attr) → "X → Y"

config/initializers/
  paper_trail.rb                          ← serializer JSON + ignore atributos sensíveis
```

### 5.3 Dependências

- **Externas (gems):** `paper_trail`.
- **Internas:** lê `current_user` (Auth).

### 5.4 Configuração crítica

```ruby
# config/initializers/paper_trail.rb
PaperTrail.config.track_associations = false
PaperTrail.serializer = PaperTrail::Serializers::JSON
```

```ruby
# Cada model auditado pode ignorar campos voláteis:
class User < ApplicationRecord
  has_paper_trail ignore: %i[
    encrypted_password reset_password_token reset_password_sent_at
    remember_created_at sign_in_count current_sign_in_at last_sign_in_at
    current_sign_in_ip last_sign_in_ip
  ]
end

class Availability < ApplicationRecord
  has_paper_trail ignore: %i[booked]   # decisão: alteração de "booked" não tem valor de negócio
end

class Payment < ApplicationRecord
  has_paper_trail only: %i[status amount paid_at expires_at]
end
```

### 5.5 UI de auditoria

`shared/_versions_table.html.erb` renderiza:

| Quando | Quem | Evento | Mudanças |
|---|---|---|---|
| 14/05 16:32 | Cibele (owner) | update | `phone`: "11 99999-1111" → "11 88888-2222" |
| 13/05 09:10 | Sistema | create | (estado inicial) |

Aparece em:
- `admin/users/show.html.erb` — aba "Histórico de alterações"
- `admin/bookings/show.html.erb` — aba "Histórico de alterações"

### 5.6 Edge cases críticos

| Caso | O que pode quebrar | Como tratar |
|---|---|---|
| Webhook do MP altera Payment sem `current_user` | `whodunnit` fica nil | Já é o comportamento desejado: ausência indica "Sistema". UI mostra "Sistema" para `whodunnit` nil |
| Job Sidekiq altera `BookingGroup#expire!` sem usuário | `whodunnit` nil | Mesmo tratamento |
| Owner muda muitas regras de desconto rapidamente | Versions crescem rápido | Em escala, criar job de purge para versions > 1 ano. **Não é problema MVP** |
| Tentar consultar histórico de tabela sem `has_paper_trail` | NoMethodError `.versions` | Guard: `if record.respond_to?(:versions)` na partial |
| Whodunnit guardado como UUID string | `User.find_by(id: version.whodunnit)` | OK — `whodunnit` é string, UUID é string |

### 5.7 Quem pode ver o histórico

- **Owner:** vê tudo.
- **Dentista:** **não** vê histórico (decisão CONTEXT 6.9).
- A partial `_versions_table` é renderizada apenas em `admin/...` views.

---

## 6. Diagrama de dependências entre módulos

```
                       ┌──────────┐
                       │   Auth   │
                       └────┬─────┘
                            │ provides current_user / role
        ┌───────────────────┼────────────────────┐
        │                   │                    │
        ▼                   ▼                    ▼
  ┌──────────┐       ┌──────────┐         ┌──────────┐
  │Scheduling│ ─────►│ Payments │         │  Admin   │
  └────┬─────┘       └────┬─────┘         └────┬─────┘
       │                  │                    │
       └────────┬─────────┴────────────────────┘
                ▼
          ┌──────────┐
          │  Audit   │  (passive — observed by all)
          └──────────┘
```

- **Auth** é fundação. Todos dependem.
- **Scheduling** chama **Payments** ao criar BookingGroup.
- **Payments** chama **Scheduling** (via `BookingGroup#confirm!`/`expire!`) ao processar webhook ou expirar.
- **Admin** lê e edita Scheduling, Auth (Users), e Audit (Versions).
- **Audit** observa todas as mutações; não chama ninguém.

---

*Mapa funcional validado.*
