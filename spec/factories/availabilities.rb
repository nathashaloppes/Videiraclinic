FactoryBot.define do
  factory :availability do
    association :clinic
    association :service
    association :dentist, factory: [:user, :dentist]

    date      { Date.current + 3.days }
    starts_at { "09:00" }
    ends_at   { "09:30" }
    status    { "available" }

    trait :booked do
      status { "booked" }
    end

    trait :past do
      date { Date.current - 1.day }
    end

    trait :within_lead_time do
      date      { Date.current }
      starts_at { 2.hours.from_now.strftime("%H:%M") }
      ends_at   { 2.hours.from_now.advance(minutes: 30).strftime("%H:%M") }
    end
  end
end
