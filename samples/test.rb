require 'gosu'
require 'wads'
#require 'rdia-games'
#require_relative '../lib/rdia-games'
require_relative '../lib/rdia-games/engine'

puts "Darren test"

include RdiaGames 

class Triangle
    attr_accessor :i
    attr_accessor :j
    attr_accessor :k

    def initialize(i, j, k) 
        if i.is_a? Point3D and j.is_a? Point3D and k.is_a? Point3D
            @i = i 
            @j = j 
            @k = k 
        else 
            puts "#{i.class.name}, #{j.class.name}, #{k.class.name}"
            raise "All parameters to construct a triangle must be Point3D"
        end
    end
end 

class GraphicsObj

    def initialize
        @objects = []
        @vertices = []
        @faces = []
    end 

    def load(filename)
        index = 1
        File.readlines(filename).each do |line|
            line = line.chomp 
            
            skip = false
            if line.length == 0
                skip = true
            elsif line[0] == "#"
                skip = true 
            end 
            if not skip 
                puts "Processing object [#{index}]: #{line}"
                index = index + 1
                tokens = line.split(" ")
                type = tokens[0]
                if type == "g"
                    @graphics_name = line[2..-1].chomp
                    @objects << @graphics_name
                    puts "Graphics #{@graphics_name}"
                elsif type == "v"
                    point = Point3D.new(tokens[1].to_f, tokens[2].to_f, tokens[3].to_f)
                    @objects << point
                    @vertices << point 
                    puts point
                elsif type == "f"
                    triangle = Triangle.new(@objects[tokens[1].to_i],
                                            @objects[tokens[2].to_i],
                                            @objects[tokens[3].to_i])
                    @faces << triangle
                    @objects << triangle
                else 
                    puts "skipping for now"
                end
            end
        end
    end
end 

puts "Going to construct the pyramid object"
pyramid = GraphicsObj.new 
pyramid.load("/Users/broemmerd/dev/graphics/pyramid2.obj")
#pyramid.load("/Users/broemmerd/dev/graphics/pumpkin_tall_10k.obj")






def test_line_intersection 
    l1 = Line2D.new(Point2D.new(4, 0), Point2D.new(6, 10))
    l2 = Line2D.new(Point2D.new(0, 3), Point2D.new(10, 7))
    puts "Line #{l1} intersects line #{l2} at #{l1.intersect(l2)}."
end

def display_quad(qfs)
    if qfs == QUAD_NW
        return "QUAD_NW"
    elsif qfs == QUAD_N
        return "QUAD_N"
    elsif qfs == QUAD_NE
        return "QUAD_NE"
    elsif qfs == QUAD_SW
        return "QUAD_SW"
    elsif qfs == QUAD_S
        return "QUAD_S"
    elsif qfs == QUAD_SE
        return "QUAD_SE"
    elsif qfs == QUAD_E
        return "QUAD_E"
    elsif qfs == QUAD_W
        return "QUAD_W"
    end
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


#test_line_intersection