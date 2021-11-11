require 'gosu'
require 'wads'

include Wads

module RdiaGames
    RDIA_SCALE = 0.001

    def initialize_rdia_games 
        $cos_cache = {}
        $sin_cache = {}
        $camera = Point3D.new(0, 0, 0)
        $center = Point3D.new(0, 0, 0)
    end 

    def rdia_sin(val)
        cached = $sin_cache[val]
        if cached.nil?
            cached = Math.sin(val)
            $sin_cache[val] = cached 
        end 
        cached
    end 

    def rdia_cos(val)
        cached = $cos_cache[val]
        if cached.nil?
            cached = Math.cos(val)
            $cos_cache[val] = cached 
        end 
        cached
    end

    def calc_point(model_point, angle_x = 0, angle_y = 0, angle_z = 0)
        # XD = X(N)-PIVX
        # YD = Y(N)-PIVY
        # ZD = Z(N)-PIVZ
        xd = model_point.x - $center.x
        yd = model_point.y - $center.y
        zd = model_point.z - $center.z

        # ZX = XD*Cos{ANGLEZ} - YD*Sin{ANGLEZ} - XD
        # ZY = XD*Sin{ANGLEZ} + YD*Cos{ANGLEZ} - YD
        z_cos = rdia_cos(angle_z)
        z_sin = rdia_sin(angle_z)
        y_cos = rdia_cos(angle_y)
        y_sin = rdia_sin(angle_y)
        x_cos = rdia_cos(angle_x)
        x_sin = rdia_sin(angle_x)

        zx = (xd * z_cos) - (yd * z_sin) - xd
        zy = (xd * z_sin) + (yd * z_cos) - yd

        # YX = [XD+ZX]*Cos{ANGLEY} - ZD*Sin{ANGLEY} - [XD+ZX]
        # YZ = [XD+ZX]*Sin{ANGLEY} + ZD*Cos{ANGLEY} - ZD
        yx = ((xd + zx) * y_cos) - (zd * y_sin) - (xd + zx)
        yz = ((xd + zx) * y_sin) + (zd * y_cos) - zd

        # XY = [YD+ZY]*Cos{ANGLEX} - [ZD+YZ]*Sin{ANGLEX} - [YD+ZY]
        # XZ = [YD+ZY]*Sin{ANGLEX} + [ZD+YZ]*Cos{ANGLEX} - [ZD+YZ]
        xy = ((yd + zy) * x_cos) - ((zd + yz) * x_sin) - (yd + zy)
        xz = ((yd + zy) * x_sin) + ((zd + yz) * x_cos) - (zd + yz)

        # XROTOFFSET = YX+ZX
        # YROTOFFSET = ZY+XY
        # ZROTOFFSET = XZ+YZ 
        x_rot_offset = yx + zx
        y_rot_offset = zy + xy 
        z_rot_offset = xz + yz

        #    Z = [ Z(N) + ZROTOFFSET + CAMZ ]
        #    X = [ X(N) + XROTOFFSET + CAMX ] /Z /SCALE +MOVEX
        #    Y = [ Y(N) + YROTOFFSET + CAMY ] /Z /SCALE +MOVEY
        z = model_point.z + z_rot_offset + $camera.z
        x = (((model_point.x + x_rot_offset + $camera.x) / z) / RDIA_SCALE)
        y = (((model_point.y + y_rot_offset + $camera.y) / z) / RDIA_SCALE)

        Point3D.new(x, y, z) 
    end


    class Point2D
        attr_accessor :x
        attr_accessor :y
        def initialize(x, y)
            @x = x 
            @y = y 
        end
        def set(x, y) 
            @x = x 
            @y = y 
        end
        def to_s 
            "Point #{x}, #{y}"
        end
    end 

    class Point3D
        attr_accessor :x
        attr_accessor :y 
        attr_accessor :z 
    
        def initialize(x, y, z) 
            @x = x 
            @y = y 
            @z = z
        end
        def set(x, y, z) 
            @x = x 
            @y = y 
            @z = z 
        end
        def to_s 
            "#{@x.round},#{@y.round},#{@z.round}"
        end
    end

    class Line2D
        attr_reader :a, :b
    
        def initialize(point1, point2)
            @a = (point1.y - point2.y).fdiv(point1.x - point2.x)
            @b = point1.y - @a*point1.x
        end
    
        def intersect(other)
            return nil if @a == other.a
            x = (other.b - @b).fdiv(@a - other.a)
            y = @a*x + @b
            Point2D.new(x,y)
        end
    
        def to_s
            "y = #{@a}x + #{@b}"
        end   
    end

    class Object3D 
        attr_accessor :model_points
        attr_accessor :render_points
        attr_accessor :angle_x
        attr_accessor :angle_y
        attr_accessor :angle_z
        attr_accessor :speed
        attr_accessor :color
        attr_accessor :visible
        attr_accessor :visible_side
        attr_accessor :is_external
        attr_accessor :render_z_order

        def initialize(color = COLOR_AQUA)
            @model_points = []
            @render_points = []
            @angle_x = 0
            @angle_y = 0
            @angle_z = 0
            @color = color
            @visible = true
            @draw_as_image = true
            @render_z_order = Z_ORDER_BORDER
        end 

        def reset_visible_side
            if @is_external
                # do nothing, the visibility is static for external walls
            else
                @visible_side = QUAD_ALL
                if @color == COLOR_RED
                    @color = COLOR_AQUA
                end
            end
        end 

        def set_visible_side(val)
            if @visible_side.nil?
                @visible_side = val 
            elsif val != @visible_side 
                if @visible_side != 0
                    puts "ERROR the visible side changing from #{@visible_side} to #{val}"
                end
                @visible_side = val  
            end 
        end

        def is_behind_us
            # This is a hack, but somewhat effective
            (0..@render_points.size-1).each do |n|
                if @render_points[n].y < -10
                    if self.is_a? Line3D
                        #puts "Not displaying a line #{self.to_s}"
                    end
                    if self.is_a? Wall 
                        #puts "Not drawing a wall"
                    end
                    @visible = false
                    return true 
                end
            end
            @visible = true
            false
        end

        def ra
            @render_points[0]
        end 
        def rb
            @render_points[1]
        end 
        def rc
            @render_points[2]
        end 
        def rd 
            @render_points[3]
        end 
        def re
            @render_points[4]
        end 
        def rf
            @render_points[5]
        end 
        def rg
            @render_points[6]
        end 
        def rh
            @render_points[7]
        end

        def ma 
            @model_points[0]
        end
        def mb
            @model_points[1]
        end
        def mc
            @model_points[2]
        end
        def md
            @model_points[3]
        end
        def me
            @model_points[4]
        end
        def mf
            @model_points[5]
        end
        def mg
            @model_points[6]
        end
        def mh
            @model_points[7]
        end

        def move_left 
            @model_points.each do |model_point|
                model_point.x = model_point.x - 5
            end
        end 
        def move_right 
            @model_points.each do |model_point|
                model_point.x = model_point.x + 5
            end
        end 
        def move_up 
            @model_points.each do |model_point|
                model_point.y = model_point.y - 5
            end
        end 
        def move_down
            @model_points.each do |model_point|
                model_point.y = model_point.y + 5
            end
        end 
        def move_away
            @model_points.each do |model_point|
                model_point.z = model_point.z - 5
            end
        end 
        def move_towards
            @model_points.each do |model_point|
                model_point.z = model_point.z + 5
            end
        end 

        def draw_quad(points, z_order_to_use = nil)
            if z_order_to_use.nil? 
                z_order_to_use = @render_z_order
            end
            if @draw_as_image 
                @img.draw_as_quad points[0].x, points[0].y, @color,
                                points[1].x, points[1].y, @color,
                                points[2].x, points[2].y, @color,
                                points[3].x, points[3].y, @color,
                                z_order_to_use
            else
                Gosu::draw_quad points[0].x, points[0].y, @color,
                                points[1].x, points[1].y, @color,
                                points[2].x, points[2].y, @color,
                                points[3].x, points[3].y, @color,
                                z_order_to_use
            end
        end 

        def draw_square(points, override_color = nil, z_order_to_use = nil)
            if z_order_to_use.nil? 
                z_order_to_use = @render_z_order
            end
            (0..3).each do |n|
                if n == 3
                    draw_line(points, n, 0, override_color, z_order_to_use)
                else 
                    draw_line(points, n, n + 1, override_color, z_order_to_use)
                end 
            end
        end
        
        def draw_line(points, index1, index2, override_color = nil, z_order_to_use = nil)
            point1 = points[index1]
            point2 = points[index2]
            color_to_use = override_color.nil? ? @color : override_color 
            z_order_to_use = z_order_to_use.nil? ? @render_z_order : z_order_to_use
            Gosu::draw_line point1.x, point1.y, color_to_use, point2.x, point2.y, color_to_use, z_order_to_use
        end

        def calc_points
            @render_points = [] 
            @model_points.each do |model_point|
                @render_points << calc_point(model_point, @angle_x, @angle_y, @angle_z)
            end 
        end 
    end 

    class Line3D < Object3D
        def initialize(a, b, color = COLOR_AQUA)
            super(color)
            @model_points << a
            @model_points << b
        end

        def render(z_order_to_use = nil)
            draw_line(@render_points, 0, 1, nil, z_order_to_use)
        end 

        def to_s 
            "Line: [#{ma}] (#{ra}) to [#{mb}] (#{rb})"
        end
    end 

    class FloorTile < Object3D
        # The x, y, z coordinates are for the upper left corner
        def initialize(x, z, length = 100, color = COLOR_WHITE)
            super(color)
            @draw_as_image = false
            @model_points << Point3D.new(x,          0, z)
            @model_points << Point3D.new(x + length, 0, z)
            @model_points << Point3D.new(x + length, 0, z + length)
            @model_points << Point3D.new(x,          0, z + length)
        end

        def render 
            draw_square([ra, rb, rc, rd])
        end 
    end

    class Wall < Object3D
        # The x, y, z coordinates are for the upper left corner
        def initialize(x, z, width, length, img, is_external = false)
            super()
            height = 100

            @model_points << Point3D.new(x,         0,          z)
            @model_points << Point3D.new(x + width, 0,          z)
            @model_points << Point3D.new(x + width, 0 - height, z)
            @model_points << Point3D.new(x,         0 - height, z)
            @model_points << Point3D.new(x,         0,          z + length)
            @model_points << Point3D.new(x + width, 0,          z + length)
            @model_points << Point3D.new(x + width, 0 - height, z + length)
            @model_points << Point3D.new(x,         0 - height, z + length)

            if img.nil? 
                # do nothing, this will get drawn as a solid color
            elsif img.is_a? String
                @img = Gosu::Image.new(img)
            elsif img.is_a? Gosu::Image
                @img = img
            else 
                raise "Invalid image parameter for wall constructor: #{img}"
            end
            
            @visible_side = QUAD_ALL
            @border_color = COLOR_WHITE

            @is_external = false 
            if is_external 
                @is_external = true
                @render_z_order = Z_ORDER_BORDER
            else 
                @render_z_order = Z_ORDER_GRAPHIC_ELEMENTS
            end
        end 

        def render 
            if not @visible 
                puts "We should not draw #{self}"
            end
            #return unless @visible
            draw_top 
            if @is_external
                # Right now, only N/S/E/W quads are used for external walls
                if @visible_side == QUAD_N 
                    draw_back
                elsif @visible_side == QUAD_S 
                    draw_front
                elsif @visible_side == QUAD_E
                    draw_left_side
                elsif @visible_side == QUAD_W 
                    draw_right_side
                end
                return 
            end

            if @visible_side == QUAD_N 
                draw_back(Z_ORDER_FOCAL_ELEMENTS)
            elsif @visible_side == QUAD_S 
                draw_front(Z_ORDER_FOCAL_ELEMENTS)
                draw_back
                draw_right_side 
                draw_left_side
            elsif @visible_side == QUAD_E
                draw_left_side(Z_ORDER_FOCAL_ELEMENTS)
                draw_back
                draw_right_side 
                draw_left_side
            elsif @visible_side == QUAD_W 
                draw_right_side(Z_ORDER_FOCAL_ELEMENTS) 
                draw_back
                draw_front 
                draw_left_side
            elsif @visible_side == QUAD_NE
                draw_back(Z_ORDER_FOCAL_ELEMENTS)
                draw_right_side(Z_ORDER_FOCAL_ELEMENTS) 
                draw_front 
                draw_left_side
            elsif @visible_side == QUAD_SE
                draw_front(Z_ORDER_FOCAL_ELEMENTS) 
                draw_right_side(Z_ORDER_FOCAL_ELEMENTS) 
                draw_back
                draw_left_side
            elsif @visible_side == QUAD_NW
                draw_back(Z_ORDER_FOCAL_ELEMENTS)
                draw_left_side(Z_ORDER_FOCAL_ELEMENTS) 
                draw_front 
                draw_right_side
            elsif @visible_side == QUAD_SW
                draw_front(Z_ORDER_FOCAL_ELEMENTS) 
                draw_left_side(Z_ORDER_FOCAL_ELEMENTS)
                draw_back
                draw_right_side
            elsif @visible_side == QUAD_ALL 
                draw_front 
                draw_back
                draw_right_side 
                draw_left_side
            else
                puts "[#{self.class.name}] Not drawing anything because visible side is #{@visible_side}."
            end
        end 

        def draw_front(z_order_to_use = nil) 
            draw_quad([ra, rb, rc, rd], z_order_to_use)
            draw_square([ra, rb, rc, rd], @border_color, z_order_to_use)
        end

        def draw_back(z_order_to_use = nil)
            draw_quad([re, rf, rg, rh], z_order_to_use)    
            draw_square([re, rf, rg, rh], @border_color, z_order_to_use)
        end

        def draw_right_side(z_order_to_use = nil)
            draw_quad([rb, rf, rg, rc], z_order_to_use)
            draw_square([rb, rf, rg, rc], @border_color, z_order_to_use)
        end 

        def draw_left_side(z_order_to_use = nil)
            draw_quad([ra, re, rh, rd], z_order_to_use)
            draw_square([ra, re, rh, rd], @border_color, z_order_to_use)
        end 

        def draw_top(z_order_to_use = nil)
            draw_quad([rd, rh, rg, rc], z_order_to_use)
            draw_square([rd, rh, rg, rc], @border_color, z_order_to_use)
        end 

        # Note in 2.5D this would never really get used
        def draw_bottom(z_order_to_use = nil) 
            draw_quad([ra, re, rf, rb], z_order_to_use)  
            draw_square([ra, re, rf, rb], @border_color, z_order_to_use)
        end
    end

    class Cube < Wall
        # The x, y, z coordinates are for the upper left corner
        def initialize(x, z, size, color = COLOR_AQUA)
            super(x, z, size, size, nil)
            @draw_as_image = false
            @color = color
        end 
    end

    class PointInsidePolygon
        # check if a given point lies inside a given polygon
        # Refer https://www.geeksforgeeks.org/check-if-two-given-line-segments-intersect/
        # for explanation of functions onSegment(),
        # orientation() and doIntersect()
        
        # Define Infinite (Using INT_MAX caused overflow problems)
        INF = 100000
        
        # Given three collinear points p, q, r,
        # the function checks if point q lies
        # on line segment 'pr'
        def onSegment(point, q, r)
            #puts "onSgement q.x <= [point.x, r.x].max   #{q.x <= [point.x, r.x].max}"
            #puts "onSgement q.x >= [point.x, r.x].min   #{q.x >= [point.x, r.x].min}"
            #puts "  q.x: #{q.x}  point.x: #{point.x}   r.x: #{r.x}  min #{[point.x, r.x].min}"
            #puts "onSgement q.y <= [point.y, r.y].max   #{q.y <= [point.y, r.y].max}"
            #puts "onSgement q.y >= [point.y, r.y].min   #{q.y >= [point.y, r.y].min}"
            if q.x <= [point.x, r.x].max and
            q.x >= [point.x, r.x].min and
            q.y <= [point.y, r.y].max and
            q.y >= [point.y, r.y].min
                return true
            end
            false
        end
        
        # To find orientation of ordered triplet (p, q, r).
        # The function returns following values
        # 0 --> p, q and r are collinear
        # 1 --> Clockwise
        # 2 --> Counterclockwise
        def orientation(point, q, r)
            val = (q.y - point.y) * (r.x - q.x) - (q.x - point.x) * (r.y - q.y)
        
            if val == 0
                return 0  # collinear
            end
            return (val > 0) ? 1 : 2  # clock or counterclock wise
        end
        
        # The function that returns true if
        # line segment 'p1q1' and 'p2q2' intersect.
        def doIntersect(p1, q1, p2, q2)
            # Find the four orientations needed for
            # general and special cases
            o1 = orientation(p1, q1, p2)   # these are ints
            o2 = orientation(p1, q1, q2)
            o3 = orientation(p2, q2, p1)
            o4 = orientation(p2, q2, q1)
        
            # General case
            if (o1 != o2 and o3 != o4)
                return true
            end
        
            # Special Cases
            # p1, q1 and p2 are collinear and
            # p2 lies on segment p1q1
            if o1 == 0 and onSegment(p1, p2, q1)
                return true
            end
        
            # p1, q1 and p2 are collinear and
            # q2 lies on segment p1q1
            if o2 == 0 and onSegment(p1, q2, q1)
                return true
            end
        
            # p2, q2 and p1 are collinear and
            # p1 lies on segment p2q2
            if o3 == 0 and onSegment(p2, p1, q2)
                return true
            end
        
            # p2, q2 and q1 are collinear and
            # q1 lies on segment p2q2
            if o4 == 0 and onSegment(p2, q1, q2)
                return true
            end
        
            # Doesn't fall in any of the above cases
            return false
        end
        
        # Returns true if the point p lies
        # inside the polygon[] with n vertices
        # isInside(Point polygon[], int n, Point p)
        def isInside(polygon, n, point)
            # There must be at least 3 vertices in polygon[]
            if (n < 3)
                return false
            end
        
            # Create a point for line segment from p to infinite
            extreme = Point2D.new(INF, point.y)
        
            # Count intersections of the above line
            # with sides of polygon
            count = 0    # int
            i = 0        # int
            loop do
                next_int = (i + 1) % n
                #puts "next_int: #{next_int}   i: #{i}"
        
                # Check if the line segment from 'p' to
                # 'extreme' intersects with the line
                # segment from 'polygon[i]' to 'polygon[next]'
                #puts "Checking intersect [#{polygon[i]}, #{polygon[next_int]}], [#{point}, #{extreme}]"
                if doIntersect(polygon[i], polygon[next_int], point, extreme)
                    #puts "#{i} did intersect"
                    # If the point 'p' is collinear with line
                    # segment 'i-next', then check if it lies
                    # on segment. If it lies, return true, otherwise false
                    if orientation(polygon[i], point, polygon[next_int]) == 0
                        #puts "#{i} was colinear"
                        return onSegment(polygon[i], point, polygon[next_int])
                    end
        
                    count = count + 1
                #else 
                #    puts "#{i} no intersect"
                end
                i = next_int
                break if i == 0
            end
        
            # Return true if count is odd, false otherwise
            #puts "returning (count % 2 == 1) for count #{count}"
            return (count % 2 == 1)  # Same as (count%2 == 1)
        end
        
        # This code is contributed by 29AjayKumar
    end 

    class RayCastData 
        attr_accessor :x
        attr_accessor :tile_x
        attr_accessor :tile_y 
        attr_accessor :map_x
        attr_accessor :map_y 
        attr_accessor :at_ray 
        attr_accessor :side
        attr_accessor :draw_start  
        attr_accessor :draw_end 
        attr_accessor :color 
        attr_accessor :orig_map_x 
        attr_accessor :orig_map_y

        def initialize(x, tile_x, tile_y, map_x, map_y, at_ray, side, draw_start, draw_end, color, orig_map_x, orig_map_y)
            @x = x 
            @tile_x = tile_x 
            @tile_y = tile_y
            @map_x = map_x 
            @map_y = map_y 
            @at_ray = at_ray 
            @side = side 
            @draw_start = draw_start 
            @draw_end = draw_end
            @color = color
            @orig_map_x = orig_map_x 
            @orig_map_y = orig_map_y
        end

        def slope
            [@map_y - @orig_map_y, @map_x - @orig_map_x]
        end 

        def quad_from_slope
            # Return the side of impact on the viewed shape from the ray
            slope_x, slope_y = slope
            if slope_x > 0
                if slope_y > 0
                    return QUAD_SW
                elsif slope_y == 0
                    return QUAD_W
                else 
                    return QUAD_NW
                end
            elsif slope_x == 0
                if slope_y > 0
                    return QUAD_S
                else 
                    return QUAD_N
                end 
            else 
                # slope_x < 0
                if slope_y > 0
                    return QUAD_SE
                elsif slope_y == 0
                    return QUAD_E
                else 
                    return QUAD_NE
                end
            end

            # Do not know or x and y equal, so we are on top of the object
            # and therefore should not display it
            QUAD_NONE
        end

        def to_s 
            "Ray x: #{@x} Tile[#{@tile_x}, #{@tile_y}] -> Map[#{@map_y}, #{@map_x}]  At: #{@at_ray}  Side: #{@side}"
        end 
    end
    
    class RayCaster 
        def initialize(world_map, screen_width, screen_height)
            @world_map = world_map
            @w = screen_width
            @h = screen_height
        end 

        def ray(x, posX, posY, dirX, dirY, planeX, planeY)
            # calculate ray position and direction
            cameraX = (2 * (x / @w.to_f)) - 1;   # x-coordinate in camera space
            rayDirX = dirX + (planeX * cameraX)
            rayDirY = dirY + (planeY * cameraX)
            # which box of the map we're in
            mapX = posX.to_i
            mapY = posY.to_i

            orig_map_x = mapX
            orig_map_y = mapY

            # length of ray from current position to next x or y-side: sideDistX, sideDistY
            
            # length of ray from one x or y-side to next x or y-side
            # these are derived as:
            # deltaDistX = sqrt(1 + (rayDirY * rayDirY) / (rayDirX * rayDirX))
            # deltaDistY = sqrt(1 + (rayDirX * rayDirX) / (rayDirY * rayDirY))
            # which can be simplified to abs(|rayDir| / rayDirX) and abs(|rayDir| / rayDirY)
            # where |rayDir| is the length of the vector (rayDirX, rayDirY). Its length,
            # unlike (dirX, dirY) is not 1, however this does not matter, only the
            # ratio between deltaDistX and deltaDistY matters, due to the way the DDA
            # stepping further below works. So the values can be computed as below.
            # Division through zero is prevented, even though technically that's not
            # needed in C++ with IEEE 754 floating point values.
            deltaDistX = (rayDirX == 0) ? 1e30 : (1 / rayDirX).abs
            deltaDistY = (rayDirY == 0) ? 1e30 : (1 / rayDirY).abs
            
            perpWallDist = nil    # double
            
            # what direction to step in x or y-direction (either +1 or -1)
            stepX = nil    # int
            stepY = nil    # int

                    
            hit = 0        # was there a wall hit? (int) (is this really a boolean)
            side = nil     # was a NS or a EW wall hit? (int) (is this really a boolean)
            # calculate step and initial sideDist
            if rayDirX < 0
                stepX = -1
                sideDistX = (posX - mapX) * deltaDistX
            else
                stepX = 1
                sideDistX = (mapX + 1.0 - posX) * deltaDistX
            end
            if rayDirY < 0
                stepY = -1
                sideDistY = (posY - mapY) * deltaDistY
            else
                stepY = 1;
                sideDistY = (mapY + 1.0 - posY) * deltaDistY
            end
            # perform DDA
            while hit == 0
                # jump to next map square, either in x-direction, or in y-direction
                if sideDistX < sideDistY
                    sideDistX += deltaDistX
                    mapX += stepX
                    side = 0
                else
                    sideDistY += deltaDistY
                    mapY += stepY
                    side = 1
                end
                # Check if ray has hit a wall
                if @world_map[mapX][mapY] > 0
                    hit = 1
                end
                #puts "#{mapY - 10}, #{mapX - 5}  #{sideDistY}, #{sideDistX}  hit: #{hit}  side: #{side}  orig: #{orig_map_y - 10}, #{orig_map_x - 5}"
            end

            # TODO get rid of draw start and end since we are not using
            #[drawStart, drawEnd, mapX, mapY, side, orig_map_x, orig_map_y]
            [0, 0, mapX, mapY, side, orig_map_x, orig_map_y]
        end
    end
end
