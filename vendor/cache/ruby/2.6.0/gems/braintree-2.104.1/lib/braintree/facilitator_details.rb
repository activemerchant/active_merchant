module Braintree
  class FacilitatorDetails # :nodoc:
    include BaseModule

    attr_reader :oauth_application_client_id
    attr_reader :oauth_application_name

    def initialize(attributes)
      set_instance_variables_from_hash attributes unless attributes.nil?
    end

    def inspect
      attr_order = [:oauth_application_client_id, :oauth_application_name]
      formatted_attrs = attr_order.map do |attr|
        "#{attr}: #{send(attr).inspect}"
      end
      "#<FacilitatorDetails #{formatted_attrs.join(", ")}>"
    end
  end
end
