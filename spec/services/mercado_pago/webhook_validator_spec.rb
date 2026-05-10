require "rails_helper"

RSpec.describe MercadoPago::WebhookValidator, type: :service do
  let(:secret)     { "real-secret-key" }
  let(:ts)         { "1704908011" }
  let(:data_id)    { "12345" }
  let(:request_id) { "req-abc-123" }
  let(:payload)    { { "data" => { "id" => data_id } } }

  def build_signature(secret:, ts:, data_id:, request_id:)
    manifest = "id:#{data_id};request-id:#{request_id};ts:#{ts}"
    v1 = OpenSSL::HMAC.hexdigest("SHA256", secret, manifest)
    "ts=#{ts},v1=#{v1}"
  end

  let(:valid_signature) { build_signature(secret: secret, ts: ts, data_id: data_id, request_id: request_id) }

  let(:request) do
    double("request",
      headers: {
        "x-signature"   => valid_signature,
        "x-request-id"  => request_id
      }
    )
  end

  around do |example|
    ClimateControl.module_eval { } rescue nil # no climate_control gem needed
    with_env("MERCADOPAGO_WEBHOOK_SECRET" => secret) { example.run }
  end

  def with_env(vars, &block)
    old = vars.transform_values { |_| ENV.delete(_key = _key) rescue nil }
    vars.each { |k, v| ENV[k] = v }
    block.call
  ensure
    vars.each { |k, _| old[k] ? ENV[k] = old[k] : ENV.delete(k) }
  end

  describe ".call" do
    it "returns true for a valid HMAC signature" do
      result = MercadoPago::WebhookValidator.call(request, payload)
      expect(result).to be true
    end

    it "returns false when signature is tampered" do
      bad_request = double("request",
        headers: {
          "x-signature"   => "ts=#{ts},v1=badhash",
          "x-request-id"  => request_id
        }
      )
      result = MercadoPago::WebhookValidator.call(bad_request, payload)
      expect(result).to be false
    end

    it "returns false when ts is missing" do
      bad_request = double("request",
        headers: { "x-signature" => "v1=abc", "x-request-id" => request_id }
      )
      expect(MercadoPago::WebhookValidator.call(bad_request, payload)).to be false
    end

    context "when secret starts with 'mock'" do
      it "skips validation and returns true" do
        ENV["MERCADOPAGO_WEBHOOK_SECRET"] = "mock-webhook-secret-replace-me"
        bad_request = double("request",
          headers: { "x-signature" => "ts=1,v1=badhash", "x-request-id" => "x" }
        )
        expect(MercadoPago::WebhookValidator.call(bad_request, payload)).to be true
        ENV["MERCADOPAGO_WEBHOOK_SECRET"] = secret
      end
    end

    context "when secret is blank" do
      it "skips validation and returns true" do
        ENV["MERCADOPAGO_WEBHOOK_SECRET"] = ""
        expect(MercadoPago::WebhookValidator.call(request, payload)).to be true
        ENV["MERCADOPAGO_WEBHOOK_SECRET"] = secret
      end
    end
  end
end
