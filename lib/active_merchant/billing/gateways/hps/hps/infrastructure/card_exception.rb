module Hps
  class CardException < HpsException

  	attr_accessor :transaction_id

    def initialize(transaction_id, code, message)

      @transaction_id=transaction_id

      super(message, code)

    end

  end
end
