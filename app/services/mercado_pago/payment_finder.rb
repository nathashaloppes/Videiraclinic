module MercadoPago
  class PaymentFinder < ApplicationService
    def initialize(provider_payment_id)
      @provider_payment_id = provider_payment_id
    end

    def call
      return success(nil) if @provider_payment_id.to_s.start_with?("SANDBOX_")

      sdk  = Mercadopago::SDK.new(ENV.fetch("MERCADOPAGO_ACCESS_TOKEN"))
      resp = sdk.payment.get(@provider_payment_id)

      if resp[:status] == 200
        success(resp[:response])
      else
        Rails.logger.warn("[MercadoPago::PaymentFinder] not found id=#{@provider_payment_id} status=#{resp[:status]}")
        success(nil)
      end
    rescue => e
      Rails.logger.error("[MercadoPago::PaymentFinder] #{e.class}: #{e.message}")
      failure(e.message)
    end
  end
end
