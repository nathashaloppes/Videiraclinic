FactoryBot.define do
  factory :payment do
    association :clinic
    association :booking_group

    amount_cents { 30_000 }
    status       { "pending" }
    gateway      { "mercadopago" }
    sequence(:gateway_id) { |n| "SANDBOX_#{n}" }
    pix_qr_code  { "00020101021226...mock_pix_code" }
    pix_qr_url   { "" }
    expires_at   { 30.minutes.from_now }

    trait :paid do
      status  { "paid" }
      paid_at { Time.current }
    end

    trait :expired do
      status     { "expired" }
      expires_at { 1.hour.ago }
    end

    trait :expired_unpaid do
      status     { "pending" }
      expires_at { 1.hour.ago }
    end
  end
end
