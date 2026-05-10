puts "Seeding database..."

# Clinic
clinic = Clinic.find_or_create_by!(cnpj: "00000000000191") do |c|
  c.name  = "Videira Dental"
  c.phone = "51999990000"
  c.email = "contato@videiradental.com.br"
end
puts "  Clinic: #{clinic.name}"

# Owner
owner = User.find_or_create_by!(email: "owner@videiradental.com.br") do |u|
  u.name     = "Proprietário Videira"
  u.password = ENV.fetch("OWNER_PASSWORD", "Owner@Videira2024!")
  u.role     = "owner"
  u.clinic   = clinic
end
puts "  Owner: #{owner.email}"

# Dentist
dentist = User.find_or_create_by!(email: "dentista@videiradental.com.br") do |u|
  u.name     = "Dr. Carlos Videira"
  u.password = ENV.fetch("OWNER_PASSWORD", "Owner@Videira2024!")
  u.role     = "dentist"
  u.clinic   = clinic
end
puts "  Dentist: #{dentist.email}"

# Patient
User.find_or_create_by!(email: "paciente@exemplo.com.br") do |u|
  u.name     = "Ana Paciente"
  u.password = ENV.fetch("OWNER_PASSWORD", "Owner@Videira2024!")
  u.role     = "patient"
  u.clinic   = clinic
end
puts "  Patient: paciente@exemplo.com.br"

# Services
[
  { name: "Consulta",     description: "Avaliação e diagnóstico",  duration_minutes: 30, price_cents: 15000 },
  { name: "Limpeza",      description: "Profilaxia dental",        duration_minutes: 45, price_cents: 18000 },
  { name: "Clareamento",  description: "Clareamento dental",       duration_minutes: 60, price_cents: 35000 },
  { name: "Extração",     description: "Extração simples",         duration_minutes: 45, price_cents: 20000 },
].each do |attrs|
  svc = Service.find_or_create_by!(name: attrs[:name], clinic: clinic) do |s|
    s.description      = attrs[:description]
    s.duration_minutes = attrs[:duration_minutes]
    s.price_cents      = attrs[:price_cents]
    s.active           = true
  end
  puts "  Service: #{svc.name} — R$ #{format('%.2f', svc.price)}"
end

# Discount rules
[
  { min_slots: 2, discount_percent: 5  },
  { min_slots: 3, discount_percent: 10 },
].each do |attrs|
  DiscountRule.find_or_create_by!(clinic: clinic, min_slots: attrs[:min_slots]) do |d|
    d.discount_percent = attrs[:discount_percent]
    d.active           = true
  end
end
puts "  Discount rules: 2 criadas"

# Availabilities for next 7 business days
consulta = Service.find_by!(name: "Consulta", clinic: clinic)
times = [["09:00", "09:30"], ["10:00", "10:30"], ["14:00", "14:30"], ["15:00", "15:30"]]

7.times do |i|
  date = Date.current + i.days
  next if date.sunday?

  times.each do |(start_t, end_t)|
    Availability.find_or_create_by!(
      clinic:    clinic,
      service:   consulta,
      dentist:   dentist,
      date:      date,
      starts_at: start_t
    ) do |a|
      a.ends_at = end_t
      a.status  = "available"
    end
  end
end
puts "  Availabilities: #{Availability.count} criadas"

puts "\nSeed concluído!"
puts "  Login owner:   owner@videiradental.com.br"
puts "  Login dentist: dentista@videiradental.com.br"
puts "  Login patient: paciente@exemplo.com.br"
puts "  Senha (todos): #{ENV.fetch('OWNER_PASSWORD', 'Owner@Videira2024!')}"
