module Braintree
  class Transaction
    class CustomerDetails # :nodoc:
      include BaseModule

      attr_reader :company
      attr_reader :email
      attr_reader :fax
      attr_reader :first_name
      attr_reader :id
      attr_reader :last_name
      attr_reader :phone
      attr_reader :website

      def initialize(attributes)
        set_instance_variables_from_hash attributes unless attributes.nil?
      end

      def inspect
        attr_order = [:id, :first_name, :last_name, :email, :company, :website, :phone, :fax]
        formatted_attrs = attr_order.map do |attr|
          "#{attr}: #{send(attr).inspect}"
        end
        "#<#{formatted_attrs.join(", ")}>"
      end
    end
  end
end
