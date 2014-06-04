require "offsite_payments"

module ActiveMerchant
  module OffsitePaymentsShim
    ActionViewHelper = ::OffsitePayments::ActionViewHelper
    Helper = ::OffsitePayments::Helper
    Notification = ::OffsitePayments::Notification
    Return = ::OffsitePayments::Return
    ActionViewHelperError = ::OffsitePayments::ActionViewHelperError

    include ::OffsitePayments::Integrations
  end
end

module OffsitePayments
  def self.mode
    ActiveMerchant::Billing::Base.integration_mode
  end
end
