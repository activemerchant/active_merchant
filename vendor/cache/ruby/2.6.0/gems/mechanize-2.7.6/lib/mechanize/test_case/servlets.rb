require 'mechanize/test_case/bad_chunking_servlet'
require 'mechanize/test_case/basic_auth_servlet'
require 'mechanize/test_case/content_type_servlet'
require 'mechanize/test_case/digest_auth_servlet'
require 'mechanize/test_case/file_upload_servlet'
require 'mechanize/test_case/form_servlet'
require 'mechanize/test_case/gzip_servlet'
require 'mechanize/test_case/header_servlet'
require 'mechanize/test_case/http_refresh_servlet'
require 'mechanize/test_case/infinite_redirect_servlet'
require 'mechanize/test_case/infinite_refresh_servlet'
require 'mechanize/test_case/many_cookies_as_string_servlet'
require 'mechanize/test_case/many_cookies_servlet'
require 'mechanize/test_case/modified_since_servlet'
require 'mechanize/test_case/ntlm_servlet'
require 'mechanize/test_case/one_cookie_no_spaces_servlet'
require 'mechanize/test_case/one_cookie_servlet'
require 'mechanize/test_case/quoted_value_cookie_servlet'
require 'mechanize/test_case/redirect_servlet'
require 'mechanize/test_case/referer_servlet'
require 'mechanize/test_case/refresh_with_empty_url'
require 'mechanize/test_case/refresh_without_url'
require 'mechanize/test_case/response_code_servlet'
require 'mechanize/test_case/robots_txt_servlet'
require 'mechanize/test_case/send_cookies_servlet'
require 'mechanize/test_case/verb_servlet'

MECHANIZE_TEST_CASE_SERVLETS = {
  '/bad_chunking'           => BadChunkingServlet,
  '/basic_auth'             => BasicAuthServlet,
  '/content_type_test'      => ContentTypeServlet,
  '/digest_auth'            => DigestAuthServlet,
  '/file_upload'            => FileUploadServlet,
  '/form post'              => FormServlet,
  '/form_post'              => FormServlet,
  '/gzip'                   => GzipServlet,
  '/http_headers'           => HeaderServlet,
  '/http_refresh'           => HttpRefreshServlet,
  '/if_modified_since'      => ModifiedSinceServlet,
  '/infinite_redirect'      => InfiniteRedirectServlet,
  '/infinite_refresh'       => InfiniteRefreshServlet,
  '/many_cookies'           => ManyCookiesServlet,
  '/many_cookies_as_string' => ManyCookiesAsStringServlet,
  '/ntlm'                   => NTLMServlet,
  '/one_cookie'             => OneCookieServlet,
  '/one_cookie_no_space'    => OneCookieNoSpacesServlet,
  '/quoted_value_cookie'    => QuotedValueCookieServlet,
  '/redirect'               => RedirectServlet,
  '/referer'                => RefererServlet,
  '/refresh_with_empty_url' => RefreshWithEmptyUrl,
  '/refresh_without_url'    => RefreshWithoutUrl,
  '/response_code'          => ResponseCodeServlet,
  '/robots.txt'             => RobotsTxtServlet,
  '/robots_txt'             => RobotsTxtServlet,
  '/send_cookies'           => SendCookiesServlet,
  '/verb'                   => VerbServlet,
}

