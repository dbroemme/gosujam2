require 'gosu'
require 'wads'
#require 'rdia-games'
#require_relative '../lib/rdia-games'
require_relative '../lib/rdia-games/engine'

puts "Darren test"

include RdiaGames 

def test_line_intersection 
    l1 = Line2D.new(Point2D.new(4, 0), Point2D.new(6, 10))
    l2 = Line2D.new(Point2D.new(0, 3), Point2D.new(10, 7))
    puts "Line #{l1} intersects line #{l2} at #{l1.intersect(l2)}."
end

        # Axis lines
        #@x_axis = ThreeDLine.new(Point3D.new(-1000, 0, 0), Point3D.new(1000, 0, 0))
        #@y_axis = ThreeDLine.new(Point3D.new(0, -AXIS_END, 0), Point3D.new(0, AXIS_END, 0))
        #@z_axis = ThreeDLine.new(Point3D.new(0, 0, -AXIS_END), Point3D.new(0, 0, AXIS_END))

            #puts "------------"
            #puts "Lets raycast"
            #ray_line =  raycast(640) 
            #puts ray_line
            #slope = ray_line.slope 
            #puts slope
            #qfs = ray_line.quad_from_slope
            #puts "Quad: #{qfs}  #{str_qfs}"
            # Send a ray the direction we are looking (direction vector)
            # and see what it hits
            #t1 = Time.now
            #raycast_for_visibility
            #t2 = Time.now
            #delta = t2 - t1 # in seconds
            #puts "Raycast took #{delta} seconds"
            #(0..1279).each do |x|
            #    ray_data = raycast(x) 
            #    puts "[#{x}]  #{ray_data}"
            #end
            #puts " "
            
            #left_ray_data = raycast(0)
            #puts "left:  #{left_ray_data}"
            #left_point = Point.new(left_ray_data.map_y * 100, left_ray_data.map_x * 100)
            #middle_ray_data = raycast(640)
            #puts "mid:   #{middle_ray_data}"
            #right_ray_data = raycast(GAME_WIDTH)
            #puts "right: #{right_ray_data}"
            #right_point = Point.new(right_ray_data.map_y * 100, right_ray_data.map_x * 100)
            #vb = [camera_point, left_point, right_point]
            #vb = visibility_polygon


test_line_intersection