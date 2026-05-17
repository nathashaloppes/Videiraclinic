# Videira Dental Clinic — DESIGN_SYSTEM.md
> Design system extraído do código React/Figma.
> Referência para recriar todas as telas em Rails + ERB + Tailwind CSS.
> Última atualização: Abril 2026

---

## 1. Identidade Visual

**Nome do produto:** Videira Dental Clinic
**Estética:** Warm, orgânica, confiável — tons terrosos com fundo creme
**Fonte:** `Prompt` (Google Fonts) — pesos 300, 400, 500, 600, 700
**Border radius padrão:** `0.625rem` (10px) — arredondado mas não excessivo
**Layout base:** `max-w-md mx-auto px-4` — mobile-first, centralizado, máx 448px

---

## 2. Tokens de Cor (CSS Variables)

Copiar exatamente para `app/assets/stylesheets/application.css`:

```css
@import url('https://fonts.googleapis.com/css2?family=Prompt:wght@300;400;500;600;700&display=swap');

:root {
  /* Cores principais */
  --background:        #fef8e1;  /* fundo creme — usado em TODA a aplicação */
  --foreground:        #3E2723;  /* texto principal — marrom escuro */
  --primary:           #5D4037;  /* marrom principal — botões, títulos, ações */
  --primary-foreground:#ffffff;  /* texto sobre primary */
  --secondary:         #8D6E63;  /* marrom médio — textos secundários, ícones */
  --secondary-foreground: #ffffff;
  --accent:            #C9B8A8;  /* bege acinzentado — slots selecionados */
  --accent-foreground: #3E2723;

  /* Cards e superfícies */
  --card:              #ffffff;  /* fundo dos cards */
  --card-foreground:   #3E2723;
  --muted:             #fef8e1;  /* mesma cor do background */
  --muted-foreground:  #8D6E63;

  /* Bordas e inputs */
  --border:            rgba(0, 0, 0, 0.1);
  --input-background:  #ffffff;
  --border-color:      #E0E0E0;  /* bordas de inputs e separadores */

  /* Estados */
  --destructive:       #d4183d;  /* erros e cancelamentos */
  --destructive-foreground: #ffffff;
  --success:           #388E3C;  /* confirmações e descontos */
  --success-bg:        #E8F5E9;  /* fundo de badges de sucesso */

  /* Pix */
  --pix-color:         #32BCAD;  /* verde Pix — exclusivo para botão/ícone Pix */

  /* Sidebar admin */
  --sidebar-primary:   #5D4037;
  --sidebar-accent:    #fef8e1;
  --sidebar-accent-foreground: #3E2723;

  /* Raio */
  --radius:            0.625rem;
  --radius-sm:         calc(var(--radius) - 4px);
  --radius-md:         calc(var(--radius) - 2px);
  --radius-lg:         var(--radius);
  --radius-xl:         calc(var(--radius) + 4px);
}

* { box-sizing: border-box; }

body {
  background-color: var(--background);
  color: var(--foreground);
  font-family: 'Prompt', sans-serif;
  font-size: 16px;
}

/* Prevenir zoom em mobile em inputs */
@media screen and (max-width: 768px) {
  input, select, textarea { font-size: 16px !important; }
}
```

---

## 3. Classes Tailwind mais usadas no projeto

### Layout base de todas as páginas
```erb
<div class="min-h-screen overflow-x-hidden" style="background-color: #fef8e1">
  <div class="max-w-md mx-auto px-4 py-6">
    <!-- conteúdo -->
  </div>
</div>
```

### Cards principais (white, rounded-3xl)
```erb
<div class="bg-white rounded-3xl p-6 shadow-lg">
  <!-- conteúdo do card -->
</div>
```

### Cards secundários (white, rounded-2xl)
```erb
<div class="bg-white rounded-2xl p-4 shadow-sm">
  <!-- conteúdo -->
</div>
```

### Botão primário (marrom, rounded-full)
```erb
<button class="w-full py-3 rounded-full text-white text-sm font-medium"
        style="background-color: #5D4037">
  Texto do botão
</button>
```

### Botão outline (borda marrom)
```erb
<button class="px-6 py-3 rounded-full border-2 text-sm font-medium"
        style="border-color: #5D4037; color: #5D4037">
  Texto do botão
</button>
```

### Botão voltar (chevron)
```erb
<%= link_to root_path, class: "mb-8 p-2 hover:bg-white/50 rounded-full inline-block" do %>
  <svg class="w-6 h-6" style="color: #5D4037" ...><!-- ChevronLeft --></svg>
<% end %>
```

### Input padrão
```erb
<input type="text"
       class="w-full px-4 py-3 rounded-2xl border text-sm bg-white"
       style="border-color: #E0E0E0; color: #3E2723"
       placeholder="Placeholder*" />
```

### Input com ícone (ex: senha com olho)
```erb
<div class="relative">
  <input type="password"
         class="w-full px-4 py-3 rounded-2xl border text-sm pr-12 bg-white"
         style="border-color: #E0E0E0; color: #3E2723" />
  <button type="button" class="absolute right-4 top-1/2 -translate-y-1/2">
    <!-- ícone Eye/EyeOff -->
  </button>
</div>
```

### Título de página (h1)
```erb
<h1 class="text-2xl mb-8" style="color: #5D4037">Título</h1>
```

### Título de seção (h2/h3)
```erb
<h2 class="text-lg font-bold mb-4" style="color: #5D4037">Seção</h2>
<p class="text-sm" style="color: #8D6E63">Subtítulo ou descrição</p>
```

### Badge de desconto / sucesso
```erb
<div class="p-3 rounded-2xl" style="background-color: #E8F5E9">
  <div class="flex justify-between items-center">
    <span class="text-xs" style="color: #388E3C">Desconto aplicado</span>
    <span class="text-xs" style="color: #388E3C">- R$ 50,00</span>
  </div>
</div>
```

### Separador
```erb
<div class="border-t pt-4" style="border-color: #E0E0E0"></div>
```

### Grid de botões de navegação (2 colunas — usado em Home e Admin)
```erb
<div class="grid grid-cols-2 gap-3 mb-8">
  <button class="bg-white rounded-2xl p-5 shadow-sm hover:shadow-md
                 transition-all active:scale-[0.98] flex items-center justify-center">
    <span class="text-sm font-semibold uppercase tracking-wide"
          style="color: #5D4037">Reservas</span>
  </button>
  <!-- ... mais botões -->
</div>
```

### Tabs (Entrar / Criar conta)
```erb
<div class="flex gap-4 mb-8 border-b" style="border-color: #E0E0E0">
  <!-- Tab ativa -->
  <button class="pb-3 px-1 border-b-2 transition-colors"
          style="border-color: #5D4037; color: #5D4037">
    Entrar
  </button>
  <!-- Tab inativa -->
  <button class="pb-3 px-1 text-gray-400">Criar conta</button>
</div>
```

---

## 4. Componentes reutilizáveis → partials ERB

### _avatar.html.erb
Exibe iniciais ou foto do usuário.

```erb
<%# Uso: <%= render 'shared/avatar', user: current_user, size: 'md' %>
<% size_classes = { 'sm' => 'w-8 h-8 text-xs', 'md' => 'w-10 h-10 text-sm', 'lg' => 'w-24 h-24 text-3xl' } %>
<% css = size_classes[size || 'md'] %>

<% if user&.avatar_url.present? %>
  <img src="<%= user.avatar_url %>"
       alt="<%= user.name %>"
       class="<%= css %> rounded-full object-cover" />
<% elsif user %>
  <% initials = user.name.split(' ').then { |p| p.length >= 2 ? "#{p.first[0]}#{p.last[0]}" : user.name[0..1] }.upcase %>
  <div class="<%= css %> rounded-full flex items-center justify-center text-white"
       style="background-color: #8D6E63">
    <%= initials %>
  </div>
<% else %>
  <div class="<%= css %> rounded-full bg-gray-300 flex items-center justify-center">
    <!-- ícone User -->
  </div>
<% end %>
```

### _back_button.html.erb
```erb
<%# Uso: <%= render 'shared/back_button', path: root_path %>
<%= link_to path, class: "mb-8 p-2 hover:bg-white/50 rounded-full inline-block" do %>
  <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6" style="color: #5D4037"
       fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
    <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7"/>
  </svg>
<% end %>
```

### _flash.html.erb
Substitui os toasts do Sonner.
```erb
<% flash.each do |type, message| %>
  <% bg = type == 'alert' ? '#d4183d' : '#5D4037' %>
  <div class="fixed top-4 right-4 z-50 px-4 py-3 rounded-2xl text-white text-sm shadow-lg"
       style="background-color: <%= bg %>"
       data-controller="flash"
       data-flash-timeout-value="3000">
    <%= message %>
  </div>
<% end %>
```

### _slot_card.html.erb
Card clicável de slot de disponibilidade (tela Home).
```erb
<%# Estados: :available, :selected, :booked %>
<% bg_color = case state
   when :selected then '#C9B8A8'
   when :booked   then '#F5F5F5'
   else '#fef8e1'
   end %>
<% text_color = state == :booked ? '#BDBDBD' : '#3E2723' %>

<button class="w-full text-left px-6 py-4 rounded-full transition-all
               <%= 'opacity-50 cursor-not-allowed' if state == :booked %>"
        style="background-color: <%= bg_color %>; color: <%= text_color %>"
        <%= 'disabled' if state == :booked %>>
  <div class="flex items-center justify-between">
    <div>
      <div class="font-medium"><%= slot.name_or_period %></div>
      <div class="text-sm opacity-70">
        (<%= slot.starts_at.strftime('%Hh') %> às <%= slot.ends_at.strftime('%Hh') %>)
        <% if state == :booked %><span class="ml-2 text-xs">• Reservado</span><% end %>
      </div>
    </div>
    <div class="font-semibold">
      R$ <%= number_to_currency(slot.price, unit: '', separator: ',', delimiter: '.') %>
    </div>
  </div>
</button>
```

### _week_selector.html.erb
Seletor de semana (tela Home e Admin).
```erb
<div class="flex items-center gap-2 bg-white rounded-2xl p-4 shadow-sm">
  <!-- Botão semana anterior -->
  <button class="p-2 rounded-full hover:bg-gray-100 disabled:opacity-30"
          data-action="click->week-selector#prev">
    <!-- ChevronLeft -->
  </button>

  <div class="flex-1 grid grid-cols-7 gap-2" data-week-selector-target="dates">
    <!-- Renderizado via Stimulus / Turbo Frame -->
  </div>

  <!-- Botão próxima semana -->
  <button class="p-2 rounded-full hover:bg-gray-100 disabled:opacity-30"
          data-action="click->week-selector#next">
    <!-- ChevronRight -->
  </button>
</div>
```

### _pix_payment.html.erb
Bloco de QR Code Pix (tela Pagamento).
```erb
<div class="bg-white border-2 rounded-2xl p-6 mb-4" style="border-color: #E0E0E0">
  <!-- QR Code gerado pelo MercadoPago -->
  <div class="w-48 h-48 mx-auto mb-4 flex items-center justify-center">
    <img src="<%= payment.pix_qr_url %>" alt="QR Code Pix" class="w-full h-full object-contain" />
  </div>

  <!-- Contador regressivo (Stimulus) -->
  <div class="text-center mb-4">
    <div class="text-sm mb-2" style="color: #5D4037">
      Tempo restante:
      <span data-controller="countdown"
            data-countdown-end-value="<%= payment.expires_at.to_i %>"
            data-countdown-target="display">--:--</span>
    </div>
  </div>

  <!-- Copia e cola -->
  <div class="bg-gray-50 rounded-xl p-3 mb-3">
    <div class="text-xs mb-1" style="color: #8D6E63">Chave PIX (copia e cola):</div>
    <div class="text-xs break-all" style="color: #3E2723"
         data-controller="clipboard"
         data-clipboard-text-value="<%= payment.pix_code %>">
      <%= payment.pix_code %>
    </div>
  </div>

  <button class="w-full py-2 rounded-full border-2 flex items-center justify-center gap-2 text-sm"
          style="border-color: #5D4037; color: #5D4037"
          data-action="click->clipboard#copy">
    Copiar chave PIX
  </button>
</div>
```

---

## 5. Layout Admin

O AdminLayout do React era uma sidebar simples. Em Rails, vira `layouts/admin.html.erb`.

### Menu items do admin (atualizado — sem Videira Shop)
```ruby
ADMIN_MENU = [
  { label: 'Reservas',       path: :admin_bookings_path },
  { label: 'Clientes',       path: :admin_users_path },
  { label: 'Disponibilidade', path: :admin_availabilities_path },
  { label: 'Descontos',      path: :admin_discount_rules_path },
]
```

### layouts/admin.html.erb (estrutura)
```erb
<!DOCTYPE html>
<html>
<head>
  <title>VDC Admin</title>
  <%= csrf_meta_tags %>
  <%= stylesheet_link_tag 'application', 'data-turbo-track': 'reload' %>
  <%= javascript_importmap_tags %>
</head>
<body style="background-color: #fef8e1; font-family: 'Prompt', sans-serif">
  <div class="min-h-screen overflow-x-hidden">
    <div class="max-w-md mx-auto px-4 py-6">

      <!-- Header com Logo + Logout -->
      <div class="flex justify-center mb-6 relative">
        <%= render 'shared/logo' %>
        <%= button_to destroy_user_session_path, method: :delete,
            class: "absolute right-0 top-0 p-2 hover:bg-white/50 rounded-full transition-colors" do %>
          <!-- LogOut icon -->
        <% end %>
      </div>

      <!-- Grid de navegação -->
      <div class="grid grid-cols-2 gap-3 mb-8">
        <% ADMIN_MENU.each do |item| %>
          <%= link_to send(item[:path]),
              class: "bg-white rounded-2xl p-5 shadow-sm hover:shadow-md
                      transition-all active:scale-[0.98] flex items-center justify-center" do %>
            <span class="text-sm font-semibold uppercase tracking-wide"
                  style="color: #5D4037"><%= item[:label] %></span>
          <% end %>
        <% end %>
      </div>

      <!-- Conteúdo da página -->
      <%= yield %>

    </div>
  </div>
</body>
</html>
```

---

## 6. Mapa de Telas: React → Rails

| Tela React | View Rails | Rota | Observações |
|-----------|------------|------|-------------|
| `Home.tsx` | `home/index.html.erb` | `GET /` | Seletor de semana + lista de slots |
| `Login.tsx` | `devise/sessions/new.html.erb` | `GET /login` | Devise customizado + OAuth Google |
| `Cadastro.tsx` | `devise/registrations/new.html.erb` | `GET /cadastro` | Devise customizado |
| `Conta.tsx` | `users/show.html.erb` | `GET /conta` | Perfil da dentista |
| `MinhasReservas.tsx` | `bookings/index.html.erb` | `GET /minhas-reservas` | Histórico por mês |
| `ConfirmarReserva.tsx` | `booking_groups/new.html.erb` | `GET /reservas/confirmar` | Resumo + desconto |
| `Pagamento.tsx` | `payments/show.html.erb` | `GET /pagamento/:id` | QR Code Pix + Turbo polling |
| `AdminReservas.tsx` | `admin/bookings/index.html.erb` | `GET /admin/reservas` | Filtro por data |
| `AdminClientes.tsx` | `admin/users/index.html.erb` | `GET /admin/clientes` | Busca por nome/CRO |
| `DetalhesCliente.tsx` | `admin/users/show.html.erb` | `GET /admin/clientes/:id` | Dados + reservas + histórico |
| `AdminConfigurar.tsx` | `admin/availabilities/index.html.erb` | `GET /admin/disponibilidade` | Criar/editar slots |
| *(novo)* | `admin/discount_rules/index.html.erb` | `GET /admin/descontos` | CRUD de regras de desconto |

---

## 7. Tradução de Interatividade: React → Stimulus

| Padrão React | Equivalente Rails/Stimulus |
|-------------|---------------------------|
| `useState` para abrir/fechar modal | Stimulus controller + `data-modal-target` |
| `useNavigate` | `Turbo.visit(url)` ou `link_to` com Turbo |
| `useState` para countdown timer | Stimulus controller `countdown_controller.js` |
| Clipboard copy | Stimulus controller `clipboard_controller.js` |
| Polling de status do Pix | Turbo Stream broadcast via ActionCable |
| Cart/carrinho de slots | Turbo Frame `<turbo-frame id="cart">` |
| Animações `motion/react` | CSS transitions + `@starting-style` |
| Formulário controlado React | Rails form helpers + Stimulus para máscaras |

### Exemplo: Countdown Stimulus (substitui o timer do Pix)
```javascript
// app/javascript/controllers/countdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display"]
  static values = { end: Number }

  connect() {
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  tick() {
    const remaining = Math.max(0, this.endValue - Math.floor(Date.now() / 1000))
    const mins = Math.floor(remaining / 60).toString().padStart(2, '0')
    const secs = (remaining % 60).toString().padStart(2, '0')
    this.displayTarget.textContent = `${mins}:${secs}`
    if (remaining === 0) clearInterval(this.interval)
  }
}
```

### Exemplo: Clipboard Stimulus
```javascript
// app/javascript/controllers/clipboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }
  static targets = ["button"]

  copy() {
    navigator.clipboard.writeText(this.textValue)
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Copiado!"
    setTimeout(() => this.buttonTarget.textContent = original, 2000)
  }
}
```

### Exemplo: Turbo Stream para status do Pix
```ruby
# app/jobs/check_payment_status_job.rb
# Quando MercadoPago confirma via webhook:
Turbo::StreamsChannel.broadcast_replace_to(
  "payment_#{payment.id}",
  target: "payment_status",
  partial: "payments/confirmed",
  locals: { payment: payment }
)
```

```erb
<!-- app/views/payments/show.html.erb -->
<%= turbo_stream_from "payment_#{@payment.id}" %>
<turbo-frame id="payment_status">
  <%= render 'payments/pending', payment: @payment %>
</turbo-frame>
```

---

## 8. Formulário de Cadastro (campos do Figma)

O React tinha estes campos — todos precisam existir no Devise:

```ruby
# config/initializers/devise.rb (campos extras)
# app/models/user.rb
# attr_accessor para campos do Devise
```

```erb
<!-- devise/registrations/new.html.erb -->
<%= form_for resource, url: registration_path(resource_name) do |f| %>
  <%= f.text_field :name,       placeholder: "Nome completo*",    class: "..." %>
  <%= f.email_field :email,     placeholder: "E-mail*",           class: "..." %>
  <%= f.password_field :password, placeholder: "Senha*",          class: "..." %>
  <%= f.password_field :password_confirmation, placeholder: "Confirmar senha*", class: "..." %>
  <%= f.telephone_field :phone, placeholder: "Número de telefone*", class: "...",
                                data: { controller: "phone-mask" } %>
  <%= f.text_field :cro_number, placeholder: "Registro CRO*",     class: "..." %>
  <%= f.text_field :specialty,  placeholder: "Área de atuação*",   class: "..." %>

  <!-- Aceite de termos -->
  <label class="flex items-start gap-2">
    <%= f.check_box :terms_accepted, class: "w-4 h-4 mt-1 rounded" %>
    <span class="text-xs" style="color: #3E2723">
      Li e aceito os
      <%= link_to "Termos de Uso e Política de Privacidade", terms_path,
                  class: "text-xs underline", style: "color: #2196F3" %>
    </span>
  </label>

  <%= f.submit "Criar conta", class: "w-full py-3 rounded-full text-white",
               style: "background-color: #5D4037" %>
<% end %>
```

---

## 9. Cores por Contexto (referência rápida)

| Contexto | Cor | Hex |
|---------|-----|-----|
| Fundo de toda página | `--background` | `#fef8e1` |
| Texto principal | `--foreground` | `#3E2723` |
| Botões primários, títulos, ações | `--primary` | `#5D4037` |
| Textos secundários, ícones | `--secondary` | `#8D6E63` |
| Slots selecionados | `--accent` | `#C9B8A8` |
| Cards e modais | `white` | `#ffffff` |
| Bordas de inputs | — | `#E0E0E0` |
| Sucesso / desconto | — | `#388E3C` / `#E8F5E9` |
| Erro / cancelamento | `--destructive` | `#d4183d` |
| Botão/ícone Pix | — | `#32BCAD` |
| Avatar sem foto | — | `#8D6E63` |

---

## 10. O que NÃO recriar (descartado do Figma)

| Componente React | Motivo |
|-----------------|--------|
| `VideiraShop.tsx` | Fora do escopo |
| `Creditos.tsx` | Fora do escopo |
| `CartContext` (produtos) | Só slots entram no carrinho |
| `motion/react` animations | Substituir por CSS transitions simples |
| `react-dnd` drag-and-drop | Não necessário — ordenação por `starts_at` |
| `canvas-confetti` | Opcional — adicionar depois se desejado |
| `AdminVideiraShop.tsx` | Fora do escopo |

---

*Videira Dental Clinic — documento vivo. Atualizar ao criar cada nova tela.*
