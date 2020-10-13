##
# This class contains an option found within SelectList.  A SelectList can
# have many Option classes associated with it.  An option can be selected by
# calling Option#tick, or Option#click.
#
# To select the first option in a list:
#
#   select_list.first.tick

class Mechanize::Form::Option
  attr_reader :value, :selected, :text, :select_list, :node

  alias :to_s :value
  alias :selected? :selected

  def initialize(node, select_list)
    @node     = node
    @text     = node.inner_text
    @value    = Mechanize::Util.html_unescape(node['value'] || node.inner_text)
    @selected = node.has_attribute? 'selected'
    @select_list = select_list # The select list this option belongs to
  end

  # Select this option
  def select
    unselect_peers
    @selected = true
  end

  # Unselect this option
  def unselect
    @selected = false
  end

  alias :tick   :select
  alias :untick :unselect

  # Toggle the selection value of this option
  def click
    unselect_peers
    @selected = !@selected
  end

  private
  def unselect_peers
    return unless Mechanize::Form::SelectList === @select_list

    @select_list.select_none
  end
end

