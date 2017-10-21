module ActiveMerchant
  def self.deprecated(message, caller=Kernel.caller[1])
    warning = caller + ": " + message
    if(respond_to?(:logger) && logger.present?)
      logger.warn(warning)
    else
      warn(warning)
    end
  end
end
