require 'gosu'
require 'wads'
#require 'rdia-games'
#require_relative '../lib/rdia-games'
require_relative '../lib/rdia-games/engine'

puts "Darren test"

include RdiaGames 

def test_line_intersection 
    l1 = IntersectionLine.new(Point2D.new(4, 0), Point2D.new(6, 10))
    l2 = IntersectionLine.new(Point2D.new(0, 3), Point2D.new(10, 7))
    puts "Line #{l1} intersects line #{l2} at #{l1.intersect(l2)}."
end

test_line_intersection