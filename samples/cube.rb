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

class ThreeDPoint
    attr_accessor :x
    attr_accessor :y 
    attr_accessor :z 

    def initialize(x, y, z) 
        @x = x 
        @y = y 
        @z = z
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
        
    end 
end

class CubeRenderDisplay < Widget
    include Gosu

    def initialize
        super(0, 0, GAME_WIDTH, GAME_HEIGHT)
        disable_border

        @x_axis_model_points = [ThreeDPoint.new(-500, 0, 0), ThreeDPoint.new(500, 0, 0)]
        @y_axis_model_points = [ThreeDPoint.new(0, -500, 0), ThreeDPoint.new(0, 500, 0)]
        @z_axis_model_points = [ThreeDPoint.new(0, 0, -500), ThreeDPoint.new(0, 0, 500)]


        @offset_x = 600
        @offset_y = 300

        @move_x = 0
        @move_y = 0

        @center_x = 0
        @center_y = 0
        @center_z = 100
        @radius = 100
        @angle_x = 0
        @angle_y = 0
        @angle_z = 0
        @speed = 5
        @mode = MODE_ISOMETRIC
        @scale = 0.5
        @scaling_speed = 0.05
        @camera_x = 0
        @camera_y = 0
        @camera_z = 500   # if this started at zero, we would be inside the cube

        @current_mouse_text = Text.new(10, 700, "0, 0")
        add_child(@current_mouse_text)
        @current_scale_text = Text.new(10, 670, "Scale: 1")
        add_child(@current_scale_text)
        @current_mode_text = Text.new(10, 640, "Mode: #{@mode}")
        add_child(@current_mode_text)


        @model_points = []
        @model_points << ThreeDPoint.new(@center_x - @radius, @center_y - @radius, @center_z + @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x + @radius, @center_y - @radius, @center_z + @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x + @radius, @center_y + @radius, @center_z + @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x - @radius, @center_y + @radius, @center_z + @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x - @radius, @center_y - @radius, @center_z - @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x + @radius, @center_y - @radius, @center_z - @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x + @radius, @center_y + @radius, @center_z - @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x - @radius, @center_y + @radius, @center_z - @radius + @camera_z)

        @camera_text = Text.new(10, 610, "Camera: #{@camera_x}, #{@camera_y}, #{@camera_z}")
        add_child(@camera_text)
        @location_text = Text.new(10, 580, "")
        add_child(@location_text)

    end 

    # This uses algorithm described in https://www.skytopia.com/project/cube/cube.html
    def calc_points
        @three_d_points = [] 
        @model_points.each do |model_point|
            @three_d_points << calc_point(model_point,
                                          @scale,
                                          @angle_x, @angle_y, @angle_z,
                                          @move_x, @move_y)
        end 
        @a = @three_d_points[0]
        @b = @three_d_points[1]
        @c = @three_d_points[2]
        @d = @three_d_points[3]
        @e = @three_d_points[4]
        @f = @three_d_points[5]
        @g = @three_d_points[6]
        @h = @three_d_points[7]

        # Line
        @line_three_d_points = []
        @x_axis_model_points.each do |lmp|
            @line_three_d_points << calc_point(lmp, @scale)
        end
        @y_axis_model_points.each do |lmp|
            @line_three_d_points << calc_point(lmp, @scale)
        end
        @z_axis_model_points.each do |lmp|
            @line_three_d_points << calc_point(lmp, @scale)
        end
    end 

    def calc_point(model_point, scale, angle_x = 0, angle_y = 0, angle_z = 0, move_x = 0, move_y = 0)
        # XD = X(N)-PIVX
        # YD = Y(N)-PIVY
        # ZD = Z(N)-PIVZ
        xd = model_point.x - @center_x
        yd = model_point.y - @center_y
        zd = model_point.z - @center_z

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

        if @mode == MODE_ISOMETRIC
            x = ((model_point.x + x_rot_offset + @camera_x) / scale) + move_x 
            y = ((model_point.y + y_rot_offset + @camera_y) / scale) + move_y
            z = model_point.z
        else 
            z = model_point.z + z_rot_offset + @camera_z
            x = (((model_point.x + x_rot_offset + @camera_x) / z) / scale) + move_x 
            y = (((model_point.y + y_rot_offset + @camera_y) / z) / scale) + move_y
        end 

        ThreeDPoint.new(x, y, z) 
    end

    def render
        Gosu.translate(@offset_x, @offset_y) do
            draw_cube
            draw_line(@line_three_d_points, 0, 1, COLOR_WHITE, 9)
            draw_line(@line_three_d_points, 2, 3, COLOR_WHITE, 9)
            draw_line(@line_three_d_points, 4, 5, COLOR_WHITE, 9)
        end 
    end

    def draw_cube 
        draw_square([@a, @b, @c, @d])
        draw_square([@a, @e, @h, @d])
        draw_square([@b, @f, @g, @c])

        draw_square([@e, @f, @g, @h])
        draw_square([@a, @e, @f, @b])
        draw_square([@d, @h, @g, @c])
    end 

    def draw_square(points)
        (0..3).each do |n|
            if n == 3
                draw_line(points, n, 0)
            else 
                draw_line(points, n, n + 1)
            end 
        end
    end
    def draw_line(points, index1, index2, color = COLOR_AQUA, z = 10)
        point1 = points[index1]
        point2 = points[index2]
        Gosu::draw_line point1.x, point1.y, color, point2.x, point2.y, color, z
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

    def handle_update update_count, mouse_x, mouse_y
        calc_points
        @current_mouse_text.label = "Mouse: #{mouse_x}, #{mouse_y}"
        @current_scale_text.label = "Scale: #{@scale}"
        @current_mode_text.label = "Mode: #{@mode}"
        @camera_text.label = "Camera: #{@camera_x}, #{@camera_y}, #{@camera_z}"
        @location_text.label = location_text 
    end

    def location_text 
        "Location: #{@a.x.round}, #{@a.y.round}, #{@a.z.round}"
    end 

    def handle_key_held_down id, mouse_x, mouse_y
        if id == Gosu::KbA
            move_left
        elsif id == Gosu::KbD
            move_right
        elsif id == Gosu::KbQ
            move_up
        elsif id == Gosu::KbE
            move_down
        elsif id == Gosu::KbW
            move_away
        elsif id == Gosu::KbS
            move_towards
        elsif id == Gosu::KbF
            @camera_x = @camera_x - @speed
        elsif id == Gosu::KbH
            @camera_x = @camera_x + @speed
        elsif id == Gosu::KbR
            @camera_y = @camera_y - @speed
        elsif id == Gosu::KbY
            @camera_y = @camera_y + @speed
        elsif id == Gosu::KbT
            @camera_z = @camera_z - @speed
        elsif id == Gosu::KbG
            @camera_z = @camera_z + @speed

        elsif id == Gosu::KbJ
            @angle_x = @angle_x - 0.05
        elsif id == Gosu::KbL
            @angle_x = @angle_x + 0.05
        elsif id == Gosu::KbU
            @angle_y = @angle_y - 0.05
        elsif id == Gosu::KbO
            @angle_y = @angle_y + 0.05
        elsif id == Gosu::KbI
            @angle_z = @angle_z - 0.05
        elsif id == Gosu::KbK
            @angle_z = @angle_z - 0.05
        end
    end

    def handle_key_press id, mouse_x, mouse_y
        if id == Gosu::KbA
            move_left
        elsif id == Gosu::KbD
            move_right
        elsif id == Gosu::KbQ
            move_up
        elsif id == Gosu::KbE
            move_down
        elsif id == Gosu::KbW
            move_away
        elsif id == Gosu::KbS
            move_towards
        elsif id == Gosu::KbF
            @camera_x = @camera_x - @speed
        elsif id == Gosu::KbH
            @camera_x = @camera_x + @speed
        elsif id == Gosu::KbR
            @camera_y = @camera_y - @speed
        elsif id == Gosu::KbY
            @camera_y = @camera_y + @speed
        elsif id == Gosu::KbT
            @camera_z = @camera_z - @speed
        elsif id == Gosu::KbG
            @camera_z = @camera_z + @speed
        elsif id == Gosu::KbJ
            @angle_x = @angle_x - 0.05
        elsif id == Gosu::KbL
            @angle_x = @angle_x + 0.05
        elsif id == Gosu::KbU
            @angle_y = @angle_y - 0.05
        elsif id == Gosu::KbO
            @angle_y = @angle_y + 0.05
        elsif id == Gosu::KbI
            @angle_z = @angle_z - 0.05
        elsif id == Gosu::KbK
            @angle_z = @angle_z - 0.05
        elsif id == Gosu::KbSpace
            if @mode == MODE_ISOMETRIC 
                @mode = MODE_REAL_THREE_D 
            else 
                @mode = MODE_ISOMETRIC
            end
        elsif id == Gosu::KbP
            @mode = MODE_REAL_THREE_D 
            @scale = 0.001
            @angle_x = 0
            @angle_y = 0
            @angle_z = 0
        elsif id == Gosu::KbUp
            @scale = @scale + @scaling_speed
        elsif id == Gosu::KbDown
            if @scale > 0.3
                @scale = @scale - 0.05
            else 
                @scale = @scale - 0.01
            end
            if @scale < 0 
                @scale = 0.001
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
