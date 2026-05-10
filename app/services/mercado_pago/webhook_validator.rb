module MercadoPago
  class WebhookValidator
    # Validates MP webhook signature.
    # Header format: x-signature: ts=1704908011,v1=abc123...
    # String to sign: "id:{data_id};request-id:{x-request-id};ts:{ts}"

    def self.call(request, payload)
      new(request, payload).call
    end

    def initialize(request, payload)
      @request = request
      @payload  = payload
      @secret   = ENV.fetch("MERCADOPAGO_WEBHOOK_SECRET", "")
    end

    def call
      return true if @secret.blank? || skip_validation?

      signature_header = @request.headers["x-signature"].to_s
      request_id       = @request.headers["x-request-id"].to_s
      data_id          = @payload.dig("data", "id").to_s

      ts, v1 = parse_signature(signature_header)
      return false if ts.nil? || v1.nil?

      manifest = "id:#{data_id};request-id:#{request_id};ts:#{ts}"
      expected = OpenSSL::HMAC.hexdigest("SHA256", @secret, manifest)

      ActiveSupport::SecurityUtils.secure_compare(expected, v1)
    end

    private

    def parse_signature(header)
      parts = header.split(",").each_with_object({}) do |part, h|
        k, v = part.split("=", 2)
        h[k.strip] = v&.strip
      end
      [parts["ts"], parts["v1"]]
    end

    def skip_validation?
      # Em sandbox com secret mock, não validamos assinatura
      @secret.start_with?("mock") || @secret == "mock-webhook-secret-replace-me"
    end
  end
end
