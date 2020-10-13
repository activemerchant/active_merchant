##
# A form label on an HTML page

class Mechanize::Page::Label
  attr_reader :node
  attr_reader :text
  attr_reader :page
  alias :to_s :text

  def initialize(node, page)
    @node = node
    @text = node.inner_text
    @page = page
  end

  def for
    (id = @node['for']) && page.search("##{id}") || nil
  end
end

