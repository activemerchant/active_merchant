#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Basic
      module Reporting
        module Response
          class PayoutCompletedResponse < Iyzipay::Client::Response
            attr_accessor :payout_completed_transactions

            def from_json(json_result)
              Mapper::PayoutCompletedResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end
