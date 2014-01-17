ActiveMerchant::Billing::Integrations::Helper.class_eval do
  alias_method :origin_add_field, :add_field

  def add_field(name, value)
    if ![Array, Hash].include?(name.class) and value.nil?
      @fields[name.to_s]
    else
      origin_add_field(name, value)
    end
  end
end
