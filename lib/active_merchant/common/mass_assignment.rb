module ActiveMerchant #:nodoc:
  module MassAssignment #:nodoc:
    def initialize(attributes = {})
      self.attributes = attributes
    end
    
    def attributes=(attributes = {})
      sanitize_for_mass_assignment(attributes).each do |key, value|
        send("#{key}=", value)
      end
    end
  end
end