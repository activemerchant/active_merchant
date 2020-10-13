module Braintree
  class AchMandate
    include BaseModule # :nodoc:

    attr_reader :accepted_at
    attr_reader :text

    def initialize(attributes)
      set_instance_variables_from_hash(attributes)
      @accepted_at = Time.parse(attributes[:accepted_at]) unless @accepted_at.class == Time
    end

  end
end
