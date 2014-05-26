module ActiveMerchant
  module Empty
    private

    def empty?(value)
      case value
      when nil
        true
      when Array, Hash
        value.empty?
      when String
        value.strip.empty?
      when Numeric
        (value == 0)
      else
        false
      end
    end
  end
end
