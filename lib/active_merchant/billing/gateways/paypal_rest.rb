module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PaypalExpressRest < Gateway
      include PaypalCommonAPI

      NON_STANDARD_LOCALE_CODES = {
          'DK' => 'da_DK',
          'IL' => 'he_IL',
          'ID' => 'id_ID',
          'JP' => 'jp_JP',
          'NO' => 'no_NO',
          'BR' => 'pt_BR',
          'RU' => 'ru_RU',
          'SE' => 'sv_SE',
          'TH' => 'th_TH',
          'TR' => 'tr_TR',
          'CN' => 'zh_CN',
          'HK' => 'zh_HK',
          'TW' => 'zh_TW'
      }
     def api_adapter
       @api_adapter ||= PaypalRestApi.new(self)
     end


      delegate :post, to: :api_adapter
    end
  end
end
