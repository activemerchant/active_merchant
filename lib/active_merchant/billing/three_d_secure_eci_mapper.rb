module ActiveMerchant
  module Billing
    module ThreeDSecureEciMapper
      NON_THREE_D_SECURE_TRANSACTION = :non_three_d_secure_transaction
      ATTEMPTED_AUTHENTICATION_TRANSACTION = :attempted_authentication_transaction
      FULLY_AUTHENTICATED_TRANSACTION = :fully_authenticated_transaction

      ECI_00_01_02_MAP = { '00' => NON_THREE_D_SECURE_TRANSACTION, '01' => ATTEMPTED_AUTHENTICATION_TRANSACTION, '02' => FULLY_AUTHENTICATED_TRANSACTION }.freeze
      ECI_05_06_07_MAP = { '05' => FULLY_AUTHENTICATED_TRANSACTION, '06' => ATTEMPTED_AUTHENTICATION_TRANSACTION, '07' => NON_THREE_D_SECURE_TRANSACTION }.freeze
      BRAND_TO_ECI_MAP = {
        american_express: ECI_05_06_07_MAP,
        dankort: ECI_05_06_07_MAP,
        diners_club: ECI_05_06_07_MAP,
        discover: ECI_05_06_07_MAP,
        elo: ECI_05_06_07_MAP,
        jcb: ECI_05_06_07_MAP,
        maestro: ECI_00_01_02_MAP,
        master: ECI_00_01_02_MAP,
        visa: ECI_05_06_07_MAP
      }.freeze

      def self.map(brand, eci)
        BRAND_TO_ECI_MAP.dig(brand, eci)
      end
    end
  end
end
