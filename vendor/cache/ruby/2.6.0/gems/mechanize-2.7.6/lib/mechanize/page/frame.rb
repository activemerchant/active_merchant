# A Frame object wraps a frame HTML element.  Frame objects can be treated
# just like Link objects.  They contain #src, the #link they refer to and a
# #name, the name of the frame they refer to.  #src and #name are aliased to
# #href and #text respectively so that a Frame object can be treated just like
# a Link.

class Mechanize::Page::Frame < Mechanize::Page::Link

  alias :src :href

  attr_reader :text
  alias :name :text

  attr_reader :node

  def initialize(node, mech, referer)
    super(node, mech, referer)
    @node = node
    @text = node['name']
    @href = node['src']
    @content = nil
  end
  
  def content
    @content ||= @mech.get @href, [], page
  end

end

