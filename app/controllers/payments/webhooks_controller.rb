class Payments::WebhooksController < ActionController::Base
  # Sem CSRF, sem autenticação — validação é feita via HMAC
  protect_from_forgery with: :null_session

  def mercadopago
    payload = JSON.parse(request.body.read)

    unless MercadoPago::WebhookValidator.call(request, payload)
      Rails.logger.warn("[Webhook] Assinatura inválida ip=#{request.remote_ip}")
      return head :unauthorized
    end

    event_type = payload["type"]
    action     = payload["action"]

    # Só processa notificações de pagamento aprovado
    if event_type == "payment" && action == "payment.updated"
      provider_id = payload.dig("data", "id").to_s

      finder = MercadoPago::PaymentFinder.call(provider_id)
      mp_data = finder.value if finder.success?

      if mp_data && mp_data["status"] == "approved"
        PaymentConfirmer.call(external_reference: mp_data["external_reference"])
      end
    end

    head :ok
  rescue JSON::ParserError
    Rails.logger.error("[Webhook] JSON inválido")
    head :bad_request
  rescue => e
    Rails.logger.error("[Webhook] #{e.class}: #{e.message}")
    head :ok  # sempre 200 para o MP não retentar em erro interno
  end
end
