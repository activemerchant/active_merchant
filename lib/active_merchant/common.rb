module ActiveMerchant  
  autoload :Connection,                'active_merchant/common/connection'
  autoload :Country,                   'active_merchant/common/country'
  autoload :ActiveMerchantError,       'active_merchant/common/error'
  autoload :ConnectionError,           'active_merchant/common/error'
  autoload :RetriableConnectionError,  'active_merchant/common/error'
  autoload :ResponseError,             'active_merchant/common/error'
  autoload :ClientCertificateError,    'active_merchant/common/error'
  autoload :PostData,                  'active_merchant/common/post_data'
  autoload :PostsData,                 'active_merchant/common/posts_data'
  autoload :RequiresParameters,        'active_merchant/common/requires_parameters'
  autoload :Utils,                     'active_merchant/common/utils'
  autoload :Validateable,              'active_merchant/common/validateable'
end