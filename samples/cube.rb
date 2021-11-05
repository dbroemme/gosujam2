require 'gosu'
require 'wads'
#require 'rdia-games'
require_relative '../lib/rdia-games'

include Wads
include RdiaGames

GAME_WIDTH = 1280
GAME_HEIGHT = 720

MODE_ISOMETRIC = "iso"
MODE_REAL_THREE_D = "real3d"

AXIS_BEGIN = -500
AXIS_END = 500

class ThreeDPoint
    attr_accessor :x
    attr_accessor :y 
    attr_accessor :z 

    def initialize(x, y, z) 
        @x = x 
        @y = y 
        @z = z
    end

    def to_s 
        "#{@x},#{@y},#{@z}"
    end
end

class ThreeDObject 
    attr_accessor :model_points
    attr_accessor :render_points
    attr_accessor :angle_x
    attr_accessor :angle_y
    attr_accessor :angle_z
    attr_accessor :speed
    attr_accessor :color
    attr_accessor :visible
    attr_accessor :scale

    attr_accessor :x
    attr_accessor :y
    attr_accessor :scale

    def initialize(color = COLOR_AQUA)
        @move_x = 0     # TODO make public?
        @move_y = 0     # TODO make public?
        clear_points 
        reset_angle_and_scale
        @color = color
        @visible = true
        @draw_as_image = true
        @scale = 1
    end 

    def is_behind_us
        # This is a hack, but somewhat effective
        (0..@render_points.size-1).each do |n|
            if @render_points[n].y < -10
                #puts "Not displaying #{self.class.name} because render point #{n} is #{render_points[n].y}"
                @visible = false
                return true 
            end
        end
        
        #elsif @model_points[1].z > $camera_z
        #    puts "Not displaying line because 1 point z #{@render_points[1].z} > #{$camera_z}"
        @visible = true
        false
    end

    def clear_points 
        @model_points = []
        @render_points = []
    end

    def reset_angle_and_scale 
        @angle_x = 0
        @angle_y = 0
        @angle_z = 0
        @scale = 0.001
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

    def draw_quad(points)
        if @draw_as_image 
            @img.draw_as_quad points[0].x, points[0].y, @color,
                              points[1].x, points[1].y, @color,
                              points[2].x, points[2].y, @color,
                              points[3].x, points[3].y, @color,
                              10
        else
            Gosu::draw_quad points[0].x, points[0].y, @color,
                            points[1].x, points[1].y, @color,
                            points[2].x, points[2].y, @color,
                            points[3].x, points[3].y, @color,
                            10
        end
    end 

    def draw_square(points, override_color = nil)
        (0..3).each do |n|
            if n == 3
                draw_line(points, n, 0, 10, override_color)
            else 
                draw_line(points, n, n + 1, 10, override_color)
            end 
        end
    end
    
    def draw_line(points, index1, index2, z = 10, override_color = nil)
        point1 = points[index1]
        point2 = points[index2]
        color_to_use = override_color.nil? ? @color : override_color 
        Gosu::draw_line point1.x, point1.y, color_to_use, point2.x, point2.y, color_to_use, z
    end

    def calc_points
        @render_points = [] 
        @model_points.each do |model_point|
            @render_points << calc_point(model_point,
                                         @scale,
                                         @angle_x, @angle_y, @angle_z,
                                         @move_x, @move_y)
        end 
    end 

    def calc_point(model_point, scale, angle_x = 0, angle_y = 0, angle_z = 0, move_x = 0, move_y = 0)
        # XD = X(N)-PIVX
        # YD = Y(N)-PIVY
        # ZD = Z(N)-PIVZ
        xd = model_point.x - $center_x
        yd = model_point.y - $center_y
        zd = model_point.z - $center_z
        #if self.is_a? Cube 
        #    puts "#{xd}, #{yd}, #{zd}"
        #end

        # ZX = XD*Cos{ANGLEZ} - YD*Sin{ANGLEZ} - XD
        # ZY = XD*Sin{ANGLEZ} + YD*Cos{ANGLEZ} - YD
        zx = (xd * Math.cos(angle_z)) - (yd * Math.sin(angle_z)) - xd
        zy = (xd * Math.sin(angle_z)) + (yd * Math.cos(angle_z)) - yd

        # YX = [XD+ZX]*Cos{ANGLEY} - ZD*Sin{ANGLEY} - [XD+ZX]
        # YZ = [XD+ZX]*Sin{ANGLEY} + ZD*Cos{ANGLEY} - ZD
        yx = ((xd + zx) * Math.cos(angle_y)) - (zd * Math.sin(angle_y)) - (xd + zx)
        yz = ((xd + zx) * Math.sin(angle_y)) + (zd * Math.cos(angle_y)) - zd

        # XY = [YD+ZY]*Cos{ANGLEX} - [ZD+YZ]*Sin{ANGLEX} - [YD+ZY]
        # XZ = [YD+ZY]*Sin{ANGLEX} + [ZD+YZ]*Cos{ANGLEX} - [ZD+YZ]
        xy = ((yd + zy) * Math.cos(angle_x)) - ((zd + yz) * Math.sin(angle_x)) - (yd + zy)
        xz = ((yd + zy) * Math.sin(angle_x)) + ((zd + yz) * Math.cos(angle_x)) - (zd + yz)

        # XROTOFFSET = YX+ZX
        # YROTOFFSET = ZY+XY
        # ZROTOFFSET = XZ+YZ 
        x_rot_offset = yx + zx
        y_rot_offset = zy + xy 
        z_rot_offset = xz + yz

        #If MODE=0
        #    X = [ X(N) + XROTOFFSET + CAMX ] /SCALE +MOVEX
        #    Y = [ Y(N) + YROTOFFSET + CAMY ] /SCALE +MOVEY
        #Else
        #    Z = [ Z(N) + ZROTOFFSET + CAMZ ]
        #    X = [ X(N) + XROTOFFSET + CAMX ] /Z /SCALE +MOVEX
        #    Y = [ Y(N) + YROTOFFSET + CAMY ] /Z /SCALE +MOVEY
        #End If

        #if @mode == MODE_ISOMETRIC
        #    x = ((model_point.x + x_rot_offset + $camera_x) / scale) + move_x 
        #    y = ((model_point.y + y_rot_offset + $camera_y) / scale) + move_y
        #    z = model_point.z
        #else 
            z = model_point.z + z_rot_offset + $camera_z
            x = (((model_point.x + x_rot_offset + $camera_x) / z) / scale) + move_x 
            y = (((model_point.y + y_rot_offset + $camera_y) / z) / scale) + move_y
        #end 

        ThreeDPoint.new(x, y, z) 
    end
end 

class ThreeDLine < ThreeDObject
    def initialize(a, b, color = COLOR_AQUA)
        super(color)
        #puts "Creating line anchored at #{a.x}, #{a.z} to #{b.x}, #{b.z} "
        reset_angle_and_scale
        @model_points << a
        @model_points << b
    end

    def a 
        @model_points[0]
    end
    def b
        @model_points[1]
    end

    def render 
        #if not $debug_once
        #    puts "line #{a.x}, #{a.z} to #{b.x}, #{b.z} drawn at #{@render_points[0].x}, #{@render_points[0].y} to #{@render_points[1].x}, #{@render_points[1].y}"
        #end
        #$debug_once = true
        draw_line(@render_points, 0, 1, 10)
    end 

    def to_s 
        "Line: #{a} (#{@render_points[0]}) to #{b} (#{@render_points[1]})"
    end
end 

class Cube < ThreeDObject
    # The x, y, z coordinates are for the upper left corner
    def initialize(x, y, z, length, color = COLOR_AQUA)
        super(color)
        @x = x 
        @y = y 
        @z = z
        @length = length
        reset
        @img = Gosu::Image.new("./media/tile5.png")
    end 

    def reset 
        reset_angle_and_scale
        @model_points << ThreeDPoint.new(@x,           @y,           @z)
        @model_points << ThreeDPoint.new(@x + @length, @y,           @z)
        @model_points << ThreeDPoint.new(@x + @length, @y - @length, @z)
        @model_points << ThreeDPoint.new(@x,           @y - @length, @z)
        @model_points << ThreeDPoint.new(@x,           @y,           @z + @length)
        @model_points << ThreeDPoint.new(@x + @length, @y,           @z + @length)
        @model_points << ThreeDPoint.new(@x + @length, @y - @length, @z + @length)
        @model_points << ThreeDPoint.new(@x,           @y - @length, @z + @length)
    end

    def render 
        a = @render_points[0]
        b = @render_points[1]
        c = @render_points[2]
        d = @render_points[3]
        e = @render_points[4]
        f = @render_points[5]
        g = @render_points[6]
        h = @render_points[7]

        # TODO figure out which of these faces are not visible
        #      what direction are we facing relative to this cube
        #      can raytracing help?
        draw_quad([a, b, c, d])    # front
        draw_square([a, b, c, d], COLOR_WHITE)

        draw_quad([b, f, g, c])    # right side
        draw_square([b, f, g, c], COLOR_WHITE)

        draw_quad([d, h, g, c])    # top
        draw_square([d, h, g, c], COLOR_WHITE)

        #draw_quad([a, e, h, d])   # left side
        #draw_square([a, e, h, d], COLOR_WHITE)

        #draw_quad([e, f, g, h])   # back     
        #draw_square([e, f, g, h], COLOR_WHITE)

        #draw_quad([a, e, f, b])   # bottom   Normally we never draw the bottom
        #draw_square([a, e, f, b], COLOR_WHITE)
    end 
end

class Wall < ThreeDObject
    # The x, y, z coordinates are for the upper left corner
    def initialize(x, z, length, img = "./media/tile5.png")
        super()
        @x = x 
        @y = 0
        @z = z
        @length = length    # right now this only supports square, so one length
        @height = 100
        reset
        @img = Gosu::Image.new(img)
    end 

    def reset 
        reset_angle_and_scale
        puts "Creating wall anchored at bottom left #{@x}, #{@z}"
        @model_points << ThreeDPoint.new(@x,           @y,           @z)
        @model_points << ThreeDPoint.new(@x + @length, @y,           @z)
        @model_points << ThreeDPoint.new(@x + @length, @y - @height, @z)
        @model_points << ThreeDPoint.new(@x,           @y - @height, @z)
        @model_points << ThreeDPoint.new(@x,           @y,           @z + @length)
        @model_points << ThreeDPoint.new(@x + @length, @y,           @z + @length)
        @model_points << ThreeDPoint.new(@x + @length, @y - @height, @z + @length)
        @model_points << ThreeDPoint.new(@x,           @y - @height, @z + @length)
    end

    def render 
        a = @render_points[0]
        b = @render_points[1]
        c = @render_points[2]
        d = @render_points[3]
        e = @render_points[4]
        f = @render_points[5]
        g = @render_points[6]
        h = @render_points[7]

        # TODO figure out which of these faces are not visible
        #      what direction are we facing relative to this cube
        #      can raytracing help?
        draw_quad([a, b, c, d])    # front
        draw_square([a, b, c, d], COLOR_WHITE)

        draw_quad([b, f, g, c])    # right side
        draw_square([b, f, g, c], COLOR_WHITE)

        draw_quad([d, h, g, c])    # top
        draw_square([d, h, g, c], COLOR_WHITE)

        #draw_quad([a, e, h, d])   # left side
        #draw_square([a, e, h, d], COLOR_WHITE)

        #draw_quad([e, f, g, h])   # back     
        #draw_square([e, f, g, h], COLOR_WHITE)

        #draw_quad([a, e, f, b])   # bottom   Normally we never draw the bottom
        #draw_square([a, e, f, b], COLOR_WHITE)
    end 
end

class CubeRender < RdiaGame
    def initialize
        super(GAME_WIDTH, GAME_HEIGHT, "Cube Render", CubeRenderDisplay.new)
        register_hold_down_key(Gosu::KbQ)    
        register_hold_down_key(Gosu::KbW)    
        register_hold_down_key(Gosu::KbE)    
        register_hold_down_key(Gosu::KbR)
        register_hold_down_key(Gosu::KbT)
        register_hold_down_key(Gosu::KbY)
        register_hold_down_key(Gosu::KbU)
        register_hold_down_key(Gosu::KbI)
        register_hold_down_key(Gosu::KbO)

        register_hold_down_key(Gosu::KbA)
        register_hold_down_key(Gosu::KbS)
        register_hold_down_key(Gosu::KbD)
        register_hold_down_key(Gosu::KbF)
        register_hold_down_key(Gosu::KbG)
        register_hold_down_key(Gosu::KbH)
        register_hold_down_key(Gosu::KbJ)
        register_hold_down_key(Gosu::KbK)
        register_hold_down_key(Gosu::KbL)

        # scaling
        register_hold_down_key(Gosu::KbUp)
        register_hold_down_key(Gosu::KbDown)

        register_hold_down_key(Gosu::KbM)
        register_hold_down_key(Gosu::KbPeriod)

    end 
end

class CubeRenderDisplay < Widget
    include Gosu

    def initialize
        super(0, 0, GAME_WIDTH, GAME_HEIGHT)
        disable_border

        @x_axis_lines = []
        @z_axis_lines = []

        @offset_x = 600
        @offset_y = 300

        $center_x = 0
        $center_y = 0
        $center_z = -300   # orig -300
        $camera_x = 0
        $camera_y = 150
        $camera_z = 800   # orig 800

        @speed = 5
        @mode = MODE_ISOMETRIC
        @continuous_movement = true
        @scaling_speed = 0.05

        # Axis lines
        #@x_axis = ThreeDLine.new(ThreeDPoint.new(-1000, 0, 0), ThreeDPoint.new(1000, 0, 0))
        #@y_axis = ThreeDLine.new(ThreeDPoint.new(0, -AXIS_END, 0), ThreeDPoint.new(0, AXIS_END, 0))
        #@z_axis = ThreeDLine.new(ThreeDPoint.new(0, 0, -AXIS_END), ThreeDPoint.new(0, 0, AXIS_END))

        # Our objects
        @cube = Cube.new(-300, 0, 300, 100, COLOR_RED)
        @all_objects = [@cube]

        @grid = GridDisplay.new(0, 0, 100, 20, 95)
        @grid.grid_x_offset = 10
        @grid.grid_y_offset = 5
        instantiate_elements(@grid, @all_objects, File.readlines("./data/editor_board.txt")) 

        #@all_objects << Cube.new(300, 0, 300, 100, COLOR_GREEN)
        #@all_objects << Cube.new(300, 0, -300, 100, COLOR_BLUE)
        #@all_objects << Cube.new(-300, 0, -300, 100, COLOR_LIME)
        #@all_objects << Cube.new(50, 0, 0, 50, COLOR_AQUA)

        # Darren
        # Floor lines. Floor is y=0, because y is really height
        x = -1000
        while x < 1050
            x_axis_line = ThreeDLine.new(ThreeDPoint.new(x, 0, -500), ThreeDPoint.new(x, 0, 8900), COLOR_WHITE)
            @x_axis_lines << x_axis_line
            @all_objects << x_axis_line
            x = x + 100
        end
        z = -500
        while z < 9010
            z_axis_line = ThreeDLine.new(ThreeDPoint.new(-1000, 0, z), ThreeDPoint.new(1000, 0, z), COLOR_PINK)
            @z_axis_lines << z_axis_line
            @all_objects << z_axis_line
            z = z + 100
        end

        @text_1 = Text.new(10, 10, "")
        add_child(@text_1)
        @text_2 = Text.new(10, 40, camera_text)
        add_child(@text_2)
        @text_3 = Text.new(10, 70, angle_text)
        add_child(@text_3)
        @text_4 = Text.new(10, 100, objects_text)
        add_child(@text_4)
        @text_5 = Text.new(10, 130, "0, 0")
        add_child(@text_5)
        @text_6 = Text.new(10, 160, center_text)
        add_child(@text_6)
        @text_7 = Text.new(10, 190, cube_text)
        add_child(@text_7)
    end 

    def instantiate_elements(grid, all_objects, dsl)         
        grid.clear_tiles
        grid_y = 89
        grid_x = -10
        dsl.each do |line|
            index = 0
            while index < line.size
                char = line[index..index+1].strip
                img = nil
                #if char == "B"
                #    img = Brick.new(@blue_brick)
                if char == "W" or char == "5"
                    img = Wall.new(grid_x * 100, grid_y * 100, 100)
                #elsif char == "Y" or char == "18"
                #    img = Dot.new(@yellow_dot)
                #elsif char == "G" or char == "19"
                #    img = Dot.new(@green_dot)
                #elsif char == "F" or char == "66"
                #    img = OutOfBounds.new(@fire_transition_tile)
                #elsif char == "T"
                #    img = DiagonalWall.new(@red_wall_nw, QUAD_NW)
                #elsif char == "V"
                #    img = DiagonalWall.new(@red_wall_ne, QUAD_NE)
                #elsif char == "X"
                #    img = DiagonalWall.new(@red_wall_sw, QUAD_SW)
                #elsif char == "Z"
                #    img = DiagonalWall.new(@red_wall_se, QUAD_SE)
                #elsif char == "E" or char == "64"
                #    img = GoalArea.new(@goal_tile)
                #elsif char == "N"
                #    img = BackgroundArea.new(@tree_tile)
                #elsif char == "D"
                #    img = BackgroundArea.new(@torch_tile)
                #elsif char == "O"
                #    img = OneWayDoor.new(@one_way_tile, @red_wall)
                #    @one_way_doors << img
                #elsif char.match?(/[[:digit:]]/)
                #    tile_index = char.to_i
                #    img = BackgroundArea.new(@tileset[tile_index])
                end
                
                if img.nil?
                    # nothing to do
                else
                    #puts "#{grid_x},#{grid_y}  =  #{char}"
                    grid.set_tile(grid_x, grid_y, img)
                    all_objects << img
                end

                grid_x = grid_x + 1
                index = index + 2
            end
            grid_x = -10
            grid_y = grid_y - 1
        end
    end 

    def modify(&block)
        @all_objects.each do |obj|
            yield obj
        end
    end

    # This uses algorithm described in https://www.skytopia.com/project/cube/cube.html
    def calc_points
        modify do |n|
            n.calc_points
        end
        @center_cube = Cube.new($center_x + 25, $center_y, $center_z, 25, COLOR_LIGHT_BLUE)
        @center_cube.calc_points
    end 

    def render
        Gosu.translate(@offset_x, @offset_y) do
            @center_cube.render

            modify do |n|
                if n.is_behind_us 
                    # do not draw 
                    #puts "Not drawing #{n.class.name}"
                else
                    n.render
                end
            end

            # TEMP so it is easier to see center cube
            @z_axis_lines.each do |z_axis_line|
                WadsConfig.instance.current_theme.font.draw_text("#{z_axis_line.a.z}", 10, z_axis_line.render_points[0].y, 10, 1, 1, COLOR_WHITE)
            end

            # TODO draw the x axis line numbers
            #@x_axis_lines.each do |x_axis_line|
                #puts "Drawing line #{x_axis_line}"
            #    WadsConfig.instance.current_theme.font.draw_text("#{x_axis_line.a.x}", x_axis_line.render_points[1].x, -x_axis_line.render_points[1].x, 10, 1, 1, COLOR_WHITE)
            #end
        end 
    end

    def handle_update update_count, mouse_x, mouse_y
        @x_axis_lines.each do |x_axis_line|
            x_axis_line.a.z = $center_z - 300
            if x_axis_line.a.z < -500
                x_axis_line.a.z = -500
            end
            #puts "Set x axis line z to #{x_axis_line}"
        end
        # TODO I guess we need to do the same thing for z axis lines because
        #      when you rotate, at some point they are not visible
        calc_points
        @text_1.label = "Mouse: #{mouse_x}, #{mouse_y}"
        @text_2.label = camera_text
        @text_3.label = angle_text
        @text_4.label = objects_text
        number_of_invisible_objects = 0
        @all_objects.each do |obj| 
            if not obj.visible
                number_of_invisible_objects = number_of_invisible_objects + 1
            end 
        end
        @text_5.label = "Invisible objs: #{number_of_invisible_objects}"
        @text_6.label = center_text
        @text_7.label = cube_text
    end

    def camera_text 
        "Camera: #{$camera_x}, #{$camera_y}, #{$camera_z}" 
    end 
    def center_text 
        "Center: #{$center_x.round}, #{$center_y.round}, #{$center_z.round}" 
    end 
    def location_text 
        "Location: #{@cube.model_points[0].x.round}, #{@cube.model_points[0].y.round}, #{@cube.model_points[0].z.round}"
    end 
    def angle_text 
        "Angle: #{@cube.angle_x.round(2)}, #{@cube.angle_y.round(2)}, #{@cube.angle_z.round(2)}"
    end 
    def axis_text 
        "X Axis: #{@x_axis_lines[0].a.z} - #{@x_axis_lines[0].b.z}"
    end
    def objects_text 
        "Num objs: #{@all_objects.size}"
    end
    def cube_text 
        "Cube: #{@cube.model_points[0].x}, #{@cube.model_points[0].y}, #{@cube.model_points[0].z}"
    end

    def handle_key_held_down id, mouse_x, mouse_y
        if @continuous_movement
            handle_movement id, mouse_x, mouse_y 
        end 
    end

    def handle_key_press id, mouse_x, mouse_y
        handle_movement(id, mouse_x, mouse_y)
        if id == Gosu::KbSpace 
            @continuous_movement = !@continuous_movement
        elsif id == Gosu::KbP
            @cube.clear_points 
            @cube.reset
            modify do |n|
                n.angle_x = 0
                n.angle_y = 0
                n.angle_z = 0
            end
        elsif id == Gosu::KbUp
            # TODO this needs to delegate to the objects
            modify do |n|
                n.scale = n.scale + @scaling_speed
            end
        elsif id == Gosu::KbDown
            # TODO this needs to delegate to the objects
            modify do |n|
                n.scale = n.scale - @scaling_speed
                if n.scale < 0 
                    n.scale = 0.001
                end
            end
        end
    end

    def handle_movement id, mouse_x, mouse_y 
        if id == Gosu::KbA
            @cube.move_left
        elsif id == Gosu::KbD
            @cube.move_right
        elsif id == Gosu::KbQ
            @cube.move_up
        elsif id == Gosu::KbE
            @cube.move_down
        elsif id == Gosu::KbW
            @cube.move_towards
        elsif id == Gosu::KbS
            @cube.move_away
        #elsif id == Gosu::KbU              # change camera elevation later, don't need it now
        #    $camera_y = $camera_y - @speed
        #elsif id == Gosu::KbO              # change camera elevation later, don't need it now
        #    $camera_y = $camera_y + @speed


        elsif id == Gosu::KbJ
            $camera_x = $camera_x + @speed
            $center_x = $center_x - @speed
        elsif id == Gosu::KbL
            $camera_x = $camera_x - @speed
            $center_x = $center_x + @speed
        elsif id == Gosu::KbI
            $camera_z = $camera_z - @speed
            $center_z = $center_z + @speed
        elsif id == Gosu::KbK
            $camera_z = $camera_z + @speed
            $center_z = $center_z - @speed
        elsif id == Gosu::KbU
            modify do |n|
                n.angle_y = n.angle_y + 0.05
            end
        elsif id == Gosu::KbO
            modify do |n|
                n.angle_y = n.angle_y - 0.05
            end
        #
        # not really used
        #
        elsif id == Gosu::KbF
            modify do |n|
                n.angle_x = n.angle_x - 0.05
            end
        elsif id == Gosu::KbH
            modify do |n|
                n.angle_x = n.angle_x + 0.05
            end
        elsif id == Gosu::KbR
            modify do |n|
                n.angle_y = n.angle_y - 0.05
            end
        elsif id == Gosu::KbY
            modify do |n|
                n.angle_y = n.angle_y + 0.05
            end
        elsif id == Gosu::KbT
            modify do |n|
                n.angle_z = n.angle_z - 0.05
            end
        elsif id == Gosu::KbG
            modify do |n|
                n.angle_z = n.angle_z + 0.05
            end

        elsif id == Gosu::KbM 
            #delta_x = Math.cos(DEG_45)
            #delta_z = Math.sin(DEG_45)
            #amount_x = delta_x * 800.to_f
            #amount_z = delta_z * 800.to_f
            #puts "Delta #{delta_x}, #{delta_z}  =>  #{amount_x}, #{amount_z}"
            #$center_x = $center_x + amount_x
            #$center_z = $center_z + amount_z
            #modify do |n|
            #    n.angle_y = DEG_45
            #end
            
            $center_z = -300
        elsif id == Gosu::KbPeriod
            $center_x = $center_x + 10
            $center_z = $center_z + 10
            modify do |n|
                n.angle_y = n.angle_y - 0.05
            end
        end
    end

    def handle_key_up id, mouse_x, mouse_y
        # nothing to do here
    end

    def handle_mouse_down mouse_x, mouse_y
        @mouse_dragging = true
    end

    def handle_mouse_up mouse_x, mouse_y
        @mouse_dragging = false
    end
end

CubeRender.new.show
