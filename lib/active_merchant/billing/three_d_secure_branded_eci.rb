module ActiveMerchant
  module Billing
    class ThreeDSecureBrandedEci
      ECI_00_01_02_MAP = { '00' => :non_three_d_secure_transaction, '01' => :attempted_authentication_transaction, '02' => :fully_authenticated_transaction }.freeze
      ECI_05_06_07_MAP = { '05' => :fully_authenticated_transaction, '06' => :attempted_authentication_transaction, '07' => :non_three_d_secure_transaction }.freeze
      BRANDED_ECI_TO_ECI = {
        american_express: ECI_05_06_07_MAP,
        dankort: ECI_05_06_07_MAP,
        diners_club: ECI_05_06_07_MAP,
        discover: ECI_05_06_07_MAP,
        elo: ECI_05_06_07_MAP,
        jcb: ECI_05_06_07_MAP,
        maestro: ECI_00_01_02_MAP,
        master: ECI_00_01_02_MAP,
        visa: ECI_05_06_07_MAP,
      }.freeze

      def initialize(brand, eci)
        @brand = brand
        @eci = eci
      end

      def generic_eci
        BRANDED_ECI_TO_ECI[@brand].try(:[], @eci)
      end
    end
  end
end
