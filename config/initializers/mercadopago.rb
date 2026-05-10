Rails.application.config.after_initialize do
  token = ENV.fetch("MERCADOPAGO_ACCESS_TOKEN", "")
  if token.blank? || token.include?("000000000")
    Rails.logger.info("[MercadoPago] Rodando em modo SANDBOX — pagamentos são simulados.")
  end
end
