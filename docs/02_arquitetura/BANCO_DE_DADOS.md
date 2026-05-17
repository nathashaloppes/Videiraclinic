# Videira Dental Clinic — BANCO_DE_DADOS.md

> Schema definitivo do banco PostgreSQL.
> Migrations prontas para rodar na ordem listada.
> Última atualização: 2026-05-09

---

## 1. Convenções

- **PK:** UUID v4 (`gen_random_uuid()` via extensão `pgcrypto`).
- **Timestamps:** `created_at` / `updated_at` em **todas** as tabelas (`t.timestamps`).
- **Timezone:** `America/Sao_Paulo` no `application.rb`. Datetimes salvos em UTC.
- **Decimais monetários:** `decimal(10, 2)` (até R$ 99.999.999,99).
- **Percentuais:** `decimal(5, 2)` (0,00 – 999,99).
- **Enums:** `integer` no banco com mapeamento em ActiveRecord enum. Ordem nunca alterada após deploy.
- **FKs:** sempre com `foreign_key: true` (cria constraint Postgres).
- **`null: false`:** padrão. Coluna nullable é exceção e deve ser justificada.
- **Índices:** justificados (busca, FK, unique). Listados na seção 4.

---

## 2. Setup inicial

Em `config/application.rb`, antes das migrations:

```ruby
module VideiraDental
  class Application < Rails::Application
    config.load_defaults 7.2
    config.time_zone = 'America/Sao_Paulo'
    config.i18n.default_locale = :"pt-BR"
    config.active_record.default_timezone = :utc

    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end
  end
end
```

---

## 3. Migrations (ordem de execução)

> Cada bloco abaixo é uma migration completa. Gerar via `rails g migration <Name>`, então **substituir o conteúdo** pelo bloco correspondente.

### 3.1 EnablePgcrypto

```ruby
class EnablePgcrypto < ActiveRecord::Migration[7.2]
  def change
    enable_extension 'pgcrypto'
  end
end
```

### 3.2 CreateClinics

```ruby
class CreateClinics < ActiveRecord::Migration[7.2]
  def change
    create_table :clinics, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.string :name,        null: false
      t.string :slug,        null: false
      t.string :owner_email, null: false
      t.timestamps
    end
    add_index :clinics, :slug, unique: true
  end
end
```

### 3.3 DeviseCreateUsers

```ruby
class DeviseCreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users, id: :uuid, default: 'gen_random_uuid()' do |t|
      # Devise (database_authenticatable + recoverable + rememberable + validatable)
      t.string   :email,                null: false, default: ""
      t.string   :encrypted_password,   null: false, default: ""
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at

      # Perfil (campos do Figma)
      t.string  :name,       null: false
      t.string  :phone
      t.string  :cro_number
      t.string  :specialty
      t.date    :birth_date
      t.string  :google_uid
      t.integer :role,       null: false, default: 1   # 0=owner, 1=dentist

      # Multi-tenant
      t.references :clinic, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :google_uid,           unique: true, where: 'google_uid IS NOT NULL'
    add_index :users, [:clinic_id, :role]
  end
end
```

> **Mudanças em relação ao migrations_reference.rb:**
> - **Removidos** os 7 campos de endereço (`street`, `street_number`, `complement`, `neighborhood`, `city`, `state`, `zip_code`). Não estão no CONTEXT.md como requisitos do MVP, não aparecem no Figma e não são usados em fluxo nenhum (cobrança Pix não exige endereço). Entram em fase futura se necessário.
> - **Avatar:** o campo `avatar_url` foi removido. Avatar usa **ActiveStorage** via `has_one_attached :avatar` no model (forma idiomática Rails para upload). Nenhuma coluna em `users`.
> - **`google_uid` index:** agora `unique` com `where: 'google_uid IS NOT NULL'` (partial index). Garante que dois usuários não compartilhem o mesmo Google account, sem bloquear cadastros email/senha.

### 3.4 ActiveStorage

```bash
rails active_storage:install
```

> Gera 3 tabelas (`active_storage_blobs`, `_attachments`, `_variant_records`) com PK UUID porque o default está configurado.

### 3.5 CreateRooms

```ruby
class CreateRooms < ActiveRecord::Migration[7.2]
  def change
    create_table :rooms, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.references :clinic, null: false, foreign_key: true, type: :uuid
      t.string :name,        null: false
      t.text   :description
      t.timestamps
    end
    add_index :rooms, :clinic_id, unique: true   # MVP: 1 room por clinic
  end
end
```

> **Mudança:** adicionado **unique index em `clinic_id`** para impor no banco a regra "uma sala por clínica no MVP". Quando mudar para multi-room, basta drop do índice. Documenta a invariante atual.

### 3.6 CreateAvailabilities

```ruby
class CreateAvailabilities < ActiveRecord::Migration[7.2]
  def change
    create_table :availabilities, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.references :room,       null: false, foreign_key: true, type: :uuid
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.date    :date,      null: false
      t.time    :starts_at, null: false
      t.time    :ends_at,   null: false
      t.decimal :price,     null: false, precision: 10, scale: 2
      t.boolean :booked,    null: false, default: false
      t.timestamps
    end
    add_index :availabilities, [:room_id, :date]
    add_index :availabilities, [:date, :booked]
    add_check_constraint :availabilities, 'ends_at > starts_at',
                         name: 'availabilities_ends_after_starts'
    add_check_constraint :availabilities, 'price > 0',
                         name: 'availabilities_price_positive'
  end
end
```

> **Mudanças:** adicionados **2 check constraints** no banco. A validação Ruby pode ser bypassada (atualizações via SQL, race condition); o constraint do Postgres garante a invariante.

### 3.7 CreateDiscountRules

```ruby
class CreateDiscountRules < ActiveRecord::Migration[7.2]
  def change
    create_table :discount_rules, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.references :clinic,           null: false, foreign_key: true, type: :uuid
      t.integer :min_slots,           null: false
      t.decimal :discount_percent,    null: false, precision: 5, scale: 2
      t.boolean :active,              null: false, default: true
      t.timestamps
    end
    add_index :discount_rules, [:clinic_id, :active]
    add_index :discount_rules, [:clinic_id, :min_slots], unique: true,
              name: 'idx_discount_rules_unique_min_slots_per_clinic'
    add_check_constraint :discount_rules, 'min_slots >= 2',
                         name: 'discount_rules_min_slots_min_2'
    add_check_constraint :discount_rules,
                         'discount_percent > 0 AND discount_percent <= 100',
                         name: 'discount_rules_discount_percent_range'
  end
end
```

> **Mudanças:**
> - **Unique index `(clinic_id, min_slots)`** — impede a dona de criar 2 regras conflitantes para a mesma quantidade. O método `DiscountRule.best_for` precisa de uma resposta determinística.
> - **Check constraints** para `min_slots >= 2` (desconto não faz sentido para 1 slot) e `discount_percent` no range (0, 100].

### 3.8 CreateBookingGroups

```ruby
class CreateBookingGroups < ActiveRecord::Migration[7.2]
  def change
    create_table :booking_groups, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.references :user,          null: false, foreign_key: true, type: :uuid
      t.references :clinic,        null: false, foreign_key: true, type: :uuid
      t.references :discount_rule, null: true,  foreign_key: true, type: :uuid
      t.decimal :subtotal,         null: false, precision: 10, scale: 2
      t.decimal :discount_percent, null: false, precision: 5,  scale: 2, default: 0
      t.decimal :discount_amount,  null: false, precision: 10, scale: 2, default: 0
      t.decimal :total,            null: false, precision: 10, scale: 2
      t.integer :status,           null: false, default: 0  # 0=pending, 1=confirmed, 2=expired, 3=cancelled
      t.timestamps
    end
    add_index :booking_groups, [:user_id, :status]
    add_index :booking_groups, [:clinic_id, :status]
    add_check_constraint :booking_groups,
                         'subtotal >= 0 AND total >= 0 AND discount_amount >= 0',
                         name: 'booking_groups_amounts_non_negative'
    add_check_constraint :booking_groups,
                         'total = subtotal - discount_amount',
                         name: 'booking_groups_total_consistency'
  end
end
```

> **Mudança:** check constraint `total = subtotal - discount_amount`. Garante consistência matemática mesmo se o cálculo for refeito no futuro com outra arquitetura.

### 3.9 CreateBookings

```ruby
class CreateBookings < ActiveRecord::Migration[7.2]
  def change
    create_table :bookings, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.references :booking_group,  null: false, foreign_key: true, type: :uuid
      t.references :availability,   null: false, foreign_key: true, type: :uuid
      t.references :user,           null: false, foreign_key: true, type: :uuid
      t.integer  :status,           null: false, default: 0  # 0=pending, 1=confirmed, 2=cancelled
      t.text     :cancel_reason
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :bookings, [:booking_group_id, :status]
    add_index :bookings, :availability_id, unique: true   # 1 slot → no máx 1 booking
    add_index :bookings, [:user_id, :status]
    add_check_constraint :bookings,
                         "(status = 2) = (cancelled_at IS NOT NULL)",
                         name: 'bookings_cancelled_consistency'
  end
end
```

> **Mudança:** check constraint que garante "se status = cancelled, `cancelled_at` está preenchido; se não, `cancelled_at` é nulo". Impede estado inconsistente.

### 3.10 CreatePayments

```ruby
class CreatePayments < ActiveRecord::Migration[7.2]
  def change
    create_table :payments, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.references :booking_group, null: false, foreign_key: true, type: :uuid
      t.string   :provider,        null: false, default: 'mercadopago'
      t.string   :provider_id
      t.text     :pix_code         # "copia e cola" Pix
      t.text     :pix_qr_url       # base64 do QR code (text porque base64 cresce)
      t.integer  :status,          null: false, default: 0  # 0=pending, 1=paid, 2=expired
      t.decimal  :amount,          null: false, precision: 10, scale: 2
      t.datetime :expires_at,      null: false
      t.datetime :paid_at
      t.timestamps
    end
    add_index :payments, [:status, :expires_at]
    add_index :payments, :booking_group_id, unique: true   # 1 payment por grupo
    add_index :payments, :provider_id, where: 'provider_id IS NOT NULL'
    add_check_constraint :payments, 'amount > 0',
                         name: 'payments_amount_positive'
    add_check_constraint :payments,
                         "(status = 1) = (paid_at IS NOT NULL)",
                         name: 'payments_paid_consistency'
  end
end
```

> **Mudanças:**
> - `pix_qr_url` mudou de `string` (255) para `text` — o que o MercadoPago retorna em `qr_code_base64` é uma string base64 grande, não uma URL. **O nome da coluna está mantido por compatibilidade com o código existente, mas conceitualmente armazena o QR como base64.** Documentado.
> - Index parcial em `provider_id` para acelerar a consulta no webhook (encontrar Payment pelo ID do MercadoPago).
> - Check `paid_at` consistente com `status = paid`.

### 3.11 PaperTrail

```bash
rails generate paper_trail:install --with-changes
```

Editar a migration gerada para usar UUID:

```ruby
class CreateVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :versions, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.string   :item_type,  null: false
      t.uuid     :item_id,    null: false
      t.string   :event,      null: false
      t.string   :whodunnit                          # UUID do user (string)
      t.jsonb    :object
      t.jsonb    :object_changes
      t.datetime :created_at
    end
    add_index :versions, %i[item_type item_id]
    add_index :versions, :whodunnit
    add_index :versions, :created_at
  end
end
```

> **Mudanças:**
> - PK `:uuid`.
> - `item_id` como `uuid` (não string), pois todos os models usam UUID.
> - `object` e `object_changes` como `jsonb` (não `text`) — performance e indexação.
> - `whodunnit` segue como `string` (PaperTrail default), armazena o UUID do user serializado.

---

## 4. Lista consolidada de índices e constraints (justificada)

| Tabela | Índice/Constraint | Tipo | Justificativa |
|---|---|---|---|
| `clinics` | `slug` | unique | Roteamento futuro por slug |
| `users` | `email` | unique | Devise validatable |
| `users` | `reset_password_token` | unique | Devise recoverable |
| `users` | `google_uid` | unique partial | OAuth: 1 conta Google = 1 user |
| `users` | `(clinic_id, role)` | composto | Listar dentistas/owner por clínica |
| `rooms` | `clinic_id` | unique | MVP: 1 room por clínica |
| `availabilities` | `(room_id, date)` | composto | Lista de slots por dia (Home + Admin) |
| `availabilities` | `(date, booked)` | composto | Filtro "disponíveis em X data" |
| `availabilities` | `ends_at > starts_at` | check | Invariante de horário |
| `availabilities` | `price > 0` | check | Invariante de preço |
| `discount_rules` | `(clinic_id, active)` | composto | `DiscountRule.active.for_clinic` |
| `discount_rules` | `(clinic_id, min_slots)` | unique | `best_for` precisa de regra única por quantidade |
| `discount_rules` | `min_slots >= 2` | check | Desconto não se aplica a 1 slot |
| `discount_rules` | `discount_percent ∈ (0,100]` | check | Sanity |
| `booking_groups` | `(user_id, status)` | composto | "Minhas reservas" filtrado por status |
| `booking_groups` | `(clinic_id, status)` | composto | Admin lista por status |
| `booking_groups` | `total = subtotal - discount_amount` | check | Consistência matemática |
| `booking_groups` | amounts >= 0 | check | Sanity |
| `bookings` | `(booking_group_id, status)` | composto | Contar bookings ativos do grupo |
| `bookings` | `availability_id` | unique | **CRÍTICO**: protege contra double-booking |
| `bookings` | `(user_id, status)` | composto | Histórico da dentista |
| `bookings` | cancelled consistency | check | `cancelled_at` ↔ status |
| `payments` | `(status, expires_at)` | composto | Job de expiração: `pending` + `expires_at < now` |
| `payments` | `booking_group_id` | unique | 1 payment por grupo |
| `payments` | `provider_id` | partial | Lookup pelo webhook |
| `payments` | `amount > 0` | check | Sanity |
| `payments` | paid consistency | check | `paid_at` ↔ status |
| `versions` | `(item_type, item_id)` | composto | PaperTrail lookup do histórico |
| `versions` | `whodunnit` | simples | "O que esta dentista alterou?" |
| `versions` | `created_at` | simples | Ordenar histórico |

---

## 5. ERD final (textual)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                  CLINIC                                      │
│  id (uuid PK), name, slug (unique), owner_email                              │
└─────────┬───────────────────────────┬──────────────────────┬─────────────────┘
          │ 1                         │ 1                    │ 1
          │                           │                      │
          │ N                         │ 1                    │ N
   ┌──────▼───────┐         ┌─────────▼────────┐    ┌────────▼───────────────┐
   │     USER      │         │       ROOM        │    │     DISCOUNT_RULE       │
   │ id, email,    │         │ id, name, descr.  │    │ id, min_slots, %, ...   │
   │ name, role,   │         └─────────┬─────────┘    └────────┬────────────────┘
   │ cro, …        │                   │ 1                     │ 1
   │ clinic_id FK  │                   │                       │
   └─────┬─────────┘                   │ N                     │ 0..N
         │                       ┌─────▼─────────────┐         │
         │                       │   AVAILABILITY     │         │
         │ N (created_by)        │ id, date,         ◄─────┐   │
         ├───────────────────────► starts_at, ends_at,│    │   │
         │                       │ price, booked     │    │   │
         │ N (dentist)           └─────┬─────────────┘    │   │
         │                             │ 1                │   │
         │                             │                  │   │
         │                             │ 0..1 (unique)    │   │
         │                       ┌─────▼─────────────┐    │   │
         │                       │      BOOKING       │    │   │
         │ N                     │ id, status,       │    │   │
         ├───────────────────────► cancel_reason,    │    │   │
         │                       │ cancelled_at      │    │   │
         │                       │ booking_group_id  │    │   │
         │                       │ availability_id   ├────┘   │
         │                       │ user_id           │        │
         │                       └─────┬─────────────┘        │
         │                             │ N                    │
         │                             │                      │
         │                             │ 1                    │
         │                       ┌─────▼─────────────┐        │
         │ N                     │  BOOKING_GROUP     │        │
         ├───────────────────────► id, subtotal,     │        │
         │ (dentist)             │ discount_*, total,│        │
         │                       │ status            ◄────────┘
         │                       │ user_id, clinic_id│
         │                       │ discount_rule_id  │
         │                       └─────┬─────────────┘
         │                             │ 1
         │                             │
         │                             │ 1 (unique)
         │                       ┌─────▼─────────────┐
         │                       │      PAYMENT       │
         │                       │ id, provider,     │
         │                       │ provider_id,      │
         │                       │ pix_code, qr_url, │
         │                       │ status, amount,   │
         │                       │ expires_at,       │
         │                       │ paid_at           │
         │                       │ booking_group_id  │
         │                       └───────────────────┘
         │
         │ N (PaperTrail whodunnit, soft-link)
         │
         ▼
   ┌─────────────────────────────────────────────────────┐
   │                     VERSION                          │
   │ id, item_type, item_id, event, whodunnit (user_id), │
   │ object (jsonb), object_changes (jsonb), created_at  │
   └─────────────────────────────────────────────────────┘
```

### Cardinalidades validadas

| Origem | Cardinalidade | Destino | Forçada por |
|---|---|---|---|
| `Clinic` → `User` | 1 → N | `users.clinic_id NOT NULL FK` | migration |
| `Clinic` → `Room` | 1 → 1 | `rooms.clinic_id` unique | unique index |
| `Clinic` → `DiscountRule` | 1 → N | `discount_rules.clinic_id` | migration |
| `Clinic` → `BookingGroup` | 1 → N | `booking_groups.clinic_id` | migration |
| `Room` → `Availability` | 1 → N | `availabilities.room_id` | migration |
| `User(owner)` → `Availability` | 1 → N | `availabilities.created_by_id` | migration |
| `User(dentist)` → `BookingGroup` | 1 → N | `booking_groups.user_id` | migration |
| `User(dentist)` → `Booking` | 1 → N | `bookings.user_id` | migration |
| `BookingGroup` → `Booking` | 1 → N | `bookings.booking_group_id` | migration |
| `Availability` → `Booking` | 1 → 0..1 | `bookings.availability_id` unique | unique index |
| `BookingGroup` → `Payment` | 1 → 1 | `payments.booking_group_id` unique | unique index |
| `BookingGroup` → `DiscountRule` | N → 0..1 | `booking_groups.discount_rule_id` nullable | migration |

---

## 6. Estados (state diagrams)

### BookingGroup.status

```
[pending] ──confirm!──► [confirmed]
   │
   ├──expire!──► [expired]   (via Sidekiq quando payment.expires_at < now)
   │
   └──(todos os bookings cancelados)──► [cancelled]
```

### Booking.status

```
[pending] ──confirm!──► [confirmed]   (chamado por BookingGroup#confirm!)
   │
   ├──cancel_expired!──► [cancelled]  (via BookingGroup#expire!)
   │
[confirmed] ──cancel!(reason)──► [cancelled]   (regra 48h)
```

### Payment.status

```
[pending] ──webhook(approved)──► [paid]
   │
   └──ExpirePaymentsJob──► [expired]   (quando expires_at < now e ainda pending)
```

### Availability.booked

```
booked: false ──BookingGroupCreator (hold)──► booked: true
                                                    │
                            ┌───────────────────────┴───────────────────────┐
                            │                                               │
                  Booking#confirm!                                Booking#cancel_expired!
                  (mantém true)                                  (volta para false)
                            │                                               │
                            ▼                                               ▼
                       (mantém true)                            booked: false
                            │
                  Booking#cancel!(reason)
                            ↓
                       booked: false
```

---

## 7. Seeds (`db/seeds.rb`)

> Mantém o conteúdo do `seeds.rb` atual com 2 ajustes.

```ruby
puts "Limpando dados existentes…"
Payment.destroy_all
Booking.destroy_all
BookingGroup.destroy_all
Availability.destroy_all
DiscountRule.destroy_all
Room.destroy_all
User.destroy_all
Clinic.destroy_all

puts "Criando Clinic…"
clinic = Clinic.create!(
  name:        "Videira Dental Clinic",
  slug:        "videira-dental",
  owner_email: ENV.fetch("OWNER_EMAIL", "videiraclinic@gmail.com")
)

puts "Criando Owner…"
owner = User.create!(
  clinic:   clinic,
  name:     "Cibele Videira",
  email:    ENV.fetch("OWNER_EMAIL", "videiraclinic@gmail.com"),
  password: ENV.fetch("OWNER_PASSWORD") { "ChangeMe!2026" },
  role:     :owner
)

puts "Criando Room…"
room = Room.create!(
  clinic:      clinic,
  name:        "Sala Principal",
  description: "Sala odontológica completa com equipamentos"
)

puts "Criando DiscountRules…"
DiscountRule.create!([
  { clinic: clinic, min_slots: 2, discount_percent: 5.0,  active: true },
  { clinic: clinic, min_slots: 3, discount_percent: 10.0, active: true },
  { clinic: clinic, min_slots: 5, discount_percent: 15.0, active: true }
])

puts "Criando Availabilities (próximos 45 dias úteis)…"
periods = [
  { starts_at: '08:00', ends_at: '12:00', price: 150.00 },
  { starts_at: '13:00', ends_at: '17:00', price: 150.00 },
  { starts_at: '17:00', ends_at: '21:00', price: 120.00 }
]

(1..45).each do |i|
  date = Date.current + i.days
  next if date.sunday?
  periods.each do |p|
    Availability.create!(
      room: room, created_by: owner,
      date: date, starts_at: p[:starts_at],
      ends_at: p[:ends_at], price: p[:price], booked: false
    )
  end
end

puts "✅ Seeds criados — #{Availability.count} slots, #{DiscountRule.count} regras."
```

> **Mudanças em relação ao seeds.rb original:**
> - **Senha do owner deixa de ser hardcoded.** Usa `ENV.fetch("OWNER_PASSWORD") { "ChangeMe!2026" }`. Senha de produção real **nunca** deve viver no repositório.
> - `Date.today` → `Date.current` (respeita `Time.zone`).

---

## 8. Comandos para rodar tudo do zero

```bash
# 1. Banco
rails db:create

# 2. pgcrypto (primeiro!)
rails g migration EnablePgcrypto
# (substituir conteúdo pelo bloco 3.1)
rails db:migrate

# 3. Configurar UUID default em config/application.rb (vide §2)

# 4. Demais migrations, na ordem 3.2 → 3.10
rails g migration CreateClinics  …  # repetir para cada
rails db:migrate

# 5. ActiveStorage
rails active_storage:install
rails db:migrate

# 6. PaperTrail
rails generate paper_trail:install --with-changes
# (editar para UUID conforme §3.11)
rails db:migrate

# 7. Seeds
rails db:seed
```

---

*Schema validado e pronto para implementação.*
