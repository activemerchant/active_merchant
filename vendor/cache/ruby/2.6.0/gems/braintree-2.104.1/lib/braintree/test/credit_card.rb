module Braintree
  module Test # :nodoc:
    # The constants contained in the Braintree::Test::CreditCardNumbers module provide
    # credit card numbers that should be used when working in the sandbox environment. The sandbox
    # will not accept any credit card numbers other than the ones listed below.
    module CreditCardNumbers
      module CardTypeIndicators
        Prepaid           = "4111111111111210"
        Commercial        = "4111111111131010"
        Payroll           = "4111111114101010"
        Healthcare        = "4111111510101010"
        DurbinRegulated   = "4111161010101010"
        Debit             = "4117101010101010"
        Unknown           = "4111111111112101"
        No                = "4111111111310101"
        IssuingBank       = "4111111141010101"
        CountryOfIssuance = "4111111111121102"
      end

      AmExes = %w[378282246310005 371449635398431 378734493671000]
      CarteBlanches = %w[30569309025904] # :nodoc:
      DinersClubs = %w[38520000023237] # :nodoc:

      Discover = "6011111111111117"
      Discovers = %w[6011111111111117 6011000990139424]
      JCBs = %w[3530111333300000 3566002020360505] # :nodoc:

      Maestro = "6304000000000000" # :nodoc:
      MasterCard = "5555555555554444"
      MasterCardInternational = "5105105105105100" # :nodoc:

      MasterCards = %w[5105105105105100 5555555555554444]

      Elo = "5066991111111118"
      Hiper = "6370950000000005"
      Hipercard = "6062820524845321"

      Visa = "4012888888881881"
      VisaInternational = "4009348888881881" # :nodoc:
      VisaPrepaid = "4500600000000061"

      Fraud = "4000111111111511"
      RiskThreshold = "4111130000000003"

      Visas = %w[4009348888881881 4012888888881881 4111111111111111 4000111111111115 4500600000000061]
      Unknowns = %w[1000000000000008]

      module FailsSandboxVerification
        AmEx       = "378734493671000"
        Discover   = "6011000990139424"
        MasterCard = "5105105105105100"
        Visa       = "4000111111111115"
        Numbers    = [AmEx, Discover, MasterCard, Visa]
      end

      module AmexPayWithPoints
        Success            = "371260714673002"
        IneligibleCard     = "378267515471109"
        InsufficientPoints = "371544868764018"
        All = [Success, IneligibleCard, InsufficientPoints]
      end

      module Disputes
        Chargeback = "4023898493988028"

        Numbers = [Chargeback]
      end

      All = AmExes + Discovers + MasterCards + Visas + AmexPayWithPoints::All
    end

    module CreditCardDefaults
      CountryOfIssuance = "USA"
      IssuingBank = "NETWORK ONLY"
    end
  end
end
