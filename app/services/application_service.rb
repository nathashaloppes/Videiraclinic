class ApplicationService
  Result = Struct.new(:success, :value, :error, keyword_init: true) do
    def success? = success
    def failure? = !success
  end

  def self.call(...)
    new(...).call
  end

  private

  def success(value = nil)
    Result.new(success: true, value: value)
  end

  def failure(error)
    Result.new(success: false, error: error)
  end
end
