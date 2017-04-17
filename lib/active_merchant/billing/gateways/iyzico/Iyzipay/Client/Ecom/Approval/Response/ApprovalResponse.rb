#!/usr/bin/env ruby
# coding: utf-8

module Iyzipay
  module Client
    module Ecom
      module Approval
        module Response
          class ApprovalResponse < Iyzipay::Client::Response
            attr_accessor :payment_transaction_id

            def from_json(json_result)
              Mapper::ApprovalResponseMapper.new.map_response(self, json_result)
            end
          end
        end
      end
    end
  end
end
