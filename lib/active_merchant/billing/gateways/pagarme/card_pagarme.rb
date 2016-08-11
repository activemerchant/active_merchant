module ActiveMerchant
  module Billing
    module CardPagarme
      def create_card(credit_card)
        month = "%02d" % credit_card.month
        year  = credit_card.year.to_s.last(2)

        card = PagarMe::Card.new({
          card_number: credit_card.number,
          card_holder_name: credit_card.name,
          card_expiration_month: month,
          card_expiration_year: year,
          card_cvv: credit_card.verification_value
        })

        card.create

        card.id
      end
    end
  end
end
