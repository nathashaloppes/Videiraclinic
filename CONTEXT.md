# Contexto técnico — Videira Dental

> Documento para recontextualizar sessões futuras de desenvolvimento. Registra decisões de arquitetura, problemas já resolvidos e convenções adotadas no projeto. Leia antes de implementar qualquer feature nova.

---

## Decisões de produto

### Cancelamento → crédito (não reembolso)
Quando uma reserva é cancelada após o pagamento confirmado, **não fazemos estorno no MercadoPago**. Em vez disso, emitimos um crédito em conta para o dentista, que pode ser usado para abater futuras reservas. Essa decisão está registrada em `ATIVIDADES.md` (itens 2.1–2.4) e ainda não foi implementada.

### Clínica única por deploy
Atualmente o sistema é single-tenant por deploy — uma instância serve uma clínica. `Clinic.first` está hardcoded em `PagesController` e `Scheduling::ServicosController`. A decisão de como escalar para multi-clínica (subdomínio, slug, ENV) ainda não foi tomada — ver `ATIVIDADES.md` item 4.

---

## Decisões técnicas

### UUIDs como chave primária
Todos os modelos usam UUID como PK (`id: :uuid` no schema). Isso causou um problema crítico com o PaperTrail (ver abaixo).

### PaperTrail — `item_id` deve ser `string`
O PaperTrail foi instalado com a migration padrão que define `item_id` como `bigint`. Como os modelos usam UUID (string), o Rails tentava converter o UUID para inteiro, resultando em `item_id = 0` em todos os registros. As queries de associação (`user.versions`) retornavam vazio porque `WHERE item_id = NULL` (UUID não castável para bigint).

**Correção aplicada:** migration `20260510024824_change_versions_item_id_to_string.rb` que converte `item_id` de `bigint` para `string`. Se recriar o banco do zero, essa migration já está incluída e resolve automaticamente.

### PaperTrail no RSpec
O PaperTrail desativa o versionamento globalmente em todos os testes por padrão. Para habilitar em um teste específico, use a tag `versioning: true`:

```ruby
describe "PaperTrail", versioning: true do
  it "tracks changes" do
    # ...
  end
end
```

Isso é feito pelo framework oficial: `require "paper_trail/frameworks/rspec"` está no `spec/rails_helper.rb`. **Não adicionar** hooks manuais de `before/after` para `PaperTrail.enabled` — o framework já cuida disso.

### `FOR UPDATE` com `.size` causa erro no PostgreSQL
Em `BookingGroupCreator`, ao fazer lock das availabilities com `FOR UPDATE`, chamar `.size` antes de `.load` gera `PG::FeatureNotSupported: ERROR: FOR UPDATE is not allowed with aggregate functions` porque o Rails traduz `.size` para `COUNT(*) FOR UPDATE`.

**Solução aplicada:** chamar `.load` na relation antes de qualquer operação que precise do tamanho:
```ruby
availabilities = Availability.where(...).lock("FOR UPDATE").load
# agora availabilities.size funciona sem nova query
```

### Enums são string-backed
Todos os enums do projeto usam strings, não inteiros (`backed_by_column_of_type(:string)`). Nos specs com shoulda-matchers, sempre usar:
```ruby
it { is_expected.to define_enum_for(:status).backed_by_column_of_type(:string).with_values(...) }
```

---

## MercadoPago

### Webhook — validação HMAC
O webhook do MercadoPago valida a assinatura via HMAC-SHA256 em `MercadoPago::WebhookValidator`. A assinatura esperada é construída como:
```
"id:{id};request-id:{x-request-id};ts:{ts}"
```
onde os valores vêm do payload e dos headers.

### Bypass de validação em testes/dev
Se `MERCADOPAGO_WEBHOOK_SECRET` começar com `mock` ou estiver em branco, o validador retorna `valid: true` sem verificar a assinatura. Isso permite testes locais sem precisar gerar HMACs reais.

### Fluxo de pagamento
1. `BookingGroupCreator` chama `MercadoPago::PixCreator` → obtém `pix_code` e `payment_id` do MP
2. O dentista vê a tela de pagamento com QR Code e countdown de 30 minutos
3. MercadoPago envia webhook `POST /webhooks/mercadopago` com `action: "payment.updated"`
4. `Webhooks::MercadoPagoController` valida assinatura, busca o pagamento via `MercadoPago::PaymentFinder` e chama `PaymentConfirmer`
5. `PaymentConfirmer` atualiza o status e faz broadcast via Turbo Streams para atualizar a tela em tempo real
6. `ExpirePaymentsJob` (Sidekiq, roda periodicamente) expira pagamentos que passaram do prazo sem confirmação

---

## Autenticação

- Devise com email/senha + Google OAuth2
- Roles: `owner`, `dentist`, `patient`
- `owner` tem acesso total ao admin, incluindo `/admin/sidekiq`
- Autorização via Pundit — policies em `app/policies/`
- `authenticate_user!` é o default no `ApplicationController`; controllers públicos usam `skip_before_action :authenticate_user!`

---

## Arquitetura de serviços

Todos os serviços herdam de `ApplicationService` e retornam `ApplicationService::Result`:
```ruby
result = AlgumServico.call(params)
result.success? # => true/false
result.value    # => dado retornado em caso de sucesso
result.error    # => mensagem de erro em caso de falha
```

Serviços existentes:
- `BookingGroupCreator` — cria grupo de reservas + gera Pix (usa `FOR UPDATE` para evitar race condition)
- `BookingCanceller` — cancela uma reserva individual (verifica prazo de 48h)
- `DiscountCalculator` — calcula desconto por quantidade de slots
- `PaymentConfirmer` — confirma pagamento e faz broadcast Turbo
- `MercadoPago::PixCreator` — integração com API do MP para gerar Pix
- `MercadoPago::PaymentFinder` — busca dados de um pagamento no MP
- `MercadoPago::WebhookValidator` — valida assinatura HMAC do webhook

---

## Infraestrutura

- **Deploy:** Kamal 2 (`config/deploy.yml`) — Docker em VPS com Traefik como proxy
- **Background jobs:** Sidekiq com Redis — `ExpirePaymentsJob` é agendado via sidekiq-cron
- **Realtime:** Turbo Streams via Action Cable (Redis como adapter)
- **Storage:** Active Storage — avatar de usuário e logo de clínica; produção usa S3 (configurar `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`, `STORAGE_BUCKET`, `STORAGE_REGION`)
- **CI:** GitHub Actions (`.github/workflows/ci.yml`) — brakeman, importmap audit, rubocop, rspec com PostgreSQL 16 e Redis 7

---

## Convenções de teste

- Framework: RSpec + FactoryBot + Shoulda-Matchers + WebMock
- Factories em `spec/factories/`
- Mocks de serviços externos (MercadoPago) com `WebMock.stub_request` ou `allow(Servico).to receive(:call)`
- Turbo broadcasts em testes: `allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)`
- Testes de webhook: o payload deve incluir `action: "payment.updated"` para o controller processar
- `PaymentFinder` retorna hash com **chaves string** (`"status"`, `"external_reference"`), não símbolos — mocks devem respeitar isso

---

## O que ainda não foi implementado

Ver `ATIVIDADES.md` para a lista completa e priorizada. Resumo:

1. Views de Serviços (admin), Clínica (admin), Perfil do usuário e Serviços públicos — **controllers existem, views não**
2. Sistema de créditos — modelo `Credit` + serviço `CreditIssuer` + abatimento no checkout
3. Emails transacionais — `BookingMailer` não foi implementado
4. Request specs para admin e fluxo de agendamento

---

## Como retomar o desenvolvimento

```bash
git clone git@github.com:iandersonf/videira-dental.git
cd videira-dental
bundle install
bin/rails db:create db:migrate db:seed
bin/dev
```

Leia `README.md` para setup completo (Google OAuth, MercadoPago, variáveis de ambiente).
Leia `ATIVIDADES.md` para o backlog priorizado.
Leia este arquivo (`CONTEXT.md`) para não redescobrir problemas já resolvidos.
