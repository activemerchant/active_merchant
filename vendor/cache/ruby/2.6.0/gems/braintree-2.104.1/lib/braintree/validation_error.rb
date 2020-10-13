module Braintree
  class ValidationError
    include BaseModule

    attr_reader :attribute
    attr_reader :code
    attr_reader :message

    def initialize(error_hash)
      # parse GraphQL response objects
      if (error_hash[:extensions] &&
          error_hash[:extensions][:errorClass] &&
          error_hash[:extensions][:errorClass] == "VALIDATION")
        error_hash[:code] = error_hash[:extensions][:legacyCode].to_i
        error_hash[:attribute] = error_hash[:path].last
      end

      set_instance_variables_from_hash error_hash
    end

    def inspect # :nodoc:
      "#<#{self.class} (#{code}) #{message}>"
    end
  end
end
