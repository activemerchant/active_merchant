module Braintree
  class FacilitatedDetails # :nodoc:
    include BaseModule

    attr_reader :merchant_id
    attr_reader :merchant_name
    attr_reader :payment_method_nonce

    def initialize(attributes)
      set_instance_variables_from_hash attributes unless attributes.nil?
    end

    def inspect
      attr_order = [:merchant_id, :merchant_name, :payment_method_nonce]
      formatted_attrs = attr_order.map do |attr|
        "#{attr}: #{send(attr).inspect}"
      end
      "#<FacilitatorDetails #{formatted_attrs.join(", ")}>"
    end
  end
end
