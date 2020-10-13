##
# This class represents an image button in a form.  Use the x and y methods to
# set the x and y positions for where the mouse "clicked".

class Mechanize::Form::ImageButton < Mechanize::Form::Button
  attr_accessor :x, :y

  def initialize *args
    @x = nil
    @y = nil
    super
  end

  def query_value
    [["#{@name}.x", (@x || 0).to_s],
     ["#{@name}.y", (@y || 0).to_s]]
  end
end

