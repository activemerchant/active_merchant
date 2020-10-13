module Braintree
  class BinData # :nodoc:
    include BaseModule

    attr_reader :commercial
    attr_reader :country_of_issuance
    attr_reader :debit
    attr_reader :durbin_regulated
    attr_reader :healthcare
    attr_reader :issuing_bank
    attr_reader :payroll
    attr_reader :prepaid
    attr_reader :product_id

    def initialize(attributes)
      set_instance_variables_from_hash attributes unless attributes.nil?
    end

    def inspect
      formatted_attrs = self.class._attributes.map do |attr|
        "#{attr}: #{send(attr).inspect}"
      end
      "#<BinData #{formatted_attrs.join(", ")}>"
    end
  end
end
