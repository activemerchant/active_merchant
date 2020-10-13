require 'nokogiri'

class Nokogiri::HTML::Document
  # Returns an array of lower-cased <meta name="ROBOTS"> tokens.  If
  # no tag is found, returns an empty array.  An optional
  # +custom_name+ specifies the name of a meta tag to look for ahead
  # of "ROBOTS".  Names are compared in a case-insensitive manner.
  def meta_robots(custom_name = nil)
    (@meta_robots ||= {})[custom_name] =
      (custom_name && parse_meta_robots(custom_name)) || parse_meta_robots('robots')
  end

  # Equivalent to meta_robots(custom_name).include?('noindex').
  def noindex?(custom_name = nil)
    meta_robots(custom_name).include?('noindex')
  end

  # Equivalent to meta_robots(custom_name).include?('nofollow').
  def nofollow?(custom_name = nil)
    meta_robots(custom_name).include?('nofollow')
  end

  private

  def parse_meta_robots(custom_name)
    pattern = /\A#{Regexp.quote(custom_name)}\z/i
    meta = css('meta[@name]').find { |element|
      element['name'].match(pattern)
    } and content = meta['content'] or return []
    content.downcase.split(/[,\s]+/)
  end
end
