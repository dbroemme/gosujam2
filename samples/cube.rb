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
        # movement left, right, up, down
        register_hold_down_key(Gosu::KbA)    
        register_hold_down_key(Gosu::KbD)    
        register_hold_down_key(Gosu::KbW)    
        register_hold_down_key(Gosu::KbS)
        # rotate forward
        register_hold_down_key(Gosu::KbJ)
        register_hold_down_key(Gosu::KbK)
        register_hold_down_key(Gosu::KbL)
        # rotate back
        register_hold_down_key(Gosu::KbU)
        register_hold_down_key(Gosu::KbI)
        register_hold_down_key(Gosu::KbO)
        # scaling
        register_hold_down_key(Gosu::KbUp)
        register_hold_down_key(Gosu::KbDown)

        register_hold_down_key(Gosu::KbF)
        register_hold_down_key(Gosu::KbT)
        register_hold_down_key(Gosu::KbH)
        register_hold_down_key(Gosu::KbG)
        register_hold_down_key(Gosu::KbV)
        register_hold_down_key(Gosu::KbB)

    end 
end

class CubeRenderDisplay < Widget
    include Gosu

    def initialize
        super(0, 0, GAME_WIDTH, GAME_HEIGHT)
        disable_border

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

        @camera_text = Text.new(10, 610, "Camera: #{@camera_x}, #{@camera_y}, #{@camera_z}")
        add_child(@camera_text)
        @location_text = Text.new(10, 580, "Location: #{@move_x}, #{@move_y}, #{@center_z}")
        add_child(@location_text)


        @model_points = []
        @model_points << ThreeDPoint.new(@center_x - @radius, @center_y - @radius, @center_z + @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x + @radius, @center_y - @radius, @center_z + @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x + @radius, @center_y + @radius, @center_z + @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x - @radius, @center_y + @radius, @center_z + @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x - @radius, @center_y - @radius, @center_z - @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x + @radius, @center_y - @radius, @center_z - @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x + @radius, @center_y + @radius, @center_z - @radius + @camera_z)
        @model_points << ThreeDPoint.new(@center_x - @radius, @center_y + @radius, @center_z - @radius + @camera_z)
    end 

    # This uses algorithm described in https://www.skytopia.com/project/cube/cube.html
    def calc_points
        @three_d_points = [] 

        @model_points.each do |model_point|
            # XD = X(N)-PIVX
            # YD = Y(N)-PIVY
            # ZD = Z(N)-PIVZ
            xd = model_point.x - @center_x
            yd = model_point.y - @center_y
            zd = model_point.z - @center_z

            # ZX = XD*Cos{ANGLEZ} - YD*Sin{ANGLEZ} - XD
            # ZY = XD*Sin{ANGLEZ} + YD*Cos{ANGLEZ} - YD
            zx = (xd * Math.cos(@angle_z)) - (yd * Math.sin(@angle_z)) - xd
            zy = (xd * Math.sin(@angle_z)) + (yd * Math.cos(@angle_z)) - yd

            # YX = [XD+ZX]*Cos{ANGLEY} - ZD*Sin{ANGLEY} - [XD+ZX]
            # YZ = [XD+ZX]*Sin{ANGLEY} + ZD*Cos{ANGLEY} - ZD
            yx = ((xd + zx) * Math.cos(@angle_y)) - (zd * Math.sin(@angle_y)) - (xd + zx)
            yz = ((xd + zx) * Math.sin(@angle_y)) + (zd * Math.cos(@angle_y)) - zd

            # XY = [YD+ZY]*Cos{ANGLEX} - [ZD+YZ]*Sin{ANGLEX} - [YD+ZY]
            # XZ = [YD+ZY]*Sin{ANGLEX} + [ZD+YZ]*Cos{ANGLEX} - [ZD+YZ]
            xy = ((yd + zy) * Math.cos(@angle_x)) - ((zd + yz) * Math.sin(@angle_x)) - (yd + zy)
            xz = ((yd + zy) * Math.sin(@angle_x)) + ((zd + yz) * Math.cos(@angle_x)) - (zd + yz)

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
                x = ((model_point.x + x_rot_offset + @camera_x) / @scale) + @move_x 
                y = ((model_point.y + y_rot_offset + @camera_y) / @scale) + @move_y
                z = model_point.z
            else 
                z = model_point.z + z_rot_offset + @camera_z
                x = (((model_point.x + x_rot_offset + @camera_x) / z) / @scale) + @move_x 
                y = (((model_point.y + y_rot_offset + @camera_y) / z) / @scale) + @move_y
            end 

            @three_d_points << ThreeDPoint.new(x, y, z) 
        end

        @a = @three_d_points[0]
        @b = @three_d_points[1]
        @c = @three_d_points[2]
        @d = @three_d_points[3]
        @e = @three_d_points[4]
        @f = @three_d_points[5]
        @g = @three_d_points[6]
        @h = @three_d_points[7]
    end

    def render
        Gosu.translate(@offset_x, @offset_y) do
            draw_cube
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
    def draw_line(points, index1, index2)
        point1 = points[index1]
        point2 = points[index2]
        Gosu::draw_line point1.x, point1.y, COLOR_AQUA, point2.x, point2.y, COLOR_AQUA, 10
    end

    def move_left 
        @move_x = @move_x - @speed
    end 
    def move_right 
        @move_x = @move_x + @speed
    end 
    def move_up 
        @move_y = @move_y - @speed
    end 
    def move_down
        @move_y = @move_y + @speed
    end 


    def handle_update update_count, mouse_x, mouse_y
        calc_points
        @current_mouse_text.label = "Mouse: #{mouse_x}, #{mouse_y}"
        @current_scale_text.label = "Scale: #{@scale}"
        @current_mode_text.label = "Mode: #{@mode}"

        @camera_text.label = "Camera: #{@camera_x}, #{@camera_y}, #{@camera_z}"
        @location_text.label = "Location: #{@move_x}, #{@move_y}, #{@center_z}"
    end

    def handle_key_held_down id, mouse_x, mouse_y
        if id == Gosu::KbA
            move_left
        elsif id == Gosu::KbD
            move_right
        elsif id == Gosu::KbW
            move_up
        elsif id == Gosu::KbS
            move_down
        elsif id == Gosu::KbJ
            @angle_x = @angle_x + 0.05
        elsif id == Gosu::KbK
            @angle_y = @angle_y + 0.05
        elsif id == Gosu::KbL
            @angle_z = @angle_z + 0.05
        elsif id == Gosu::KbU
            @angle_x = @angle_x - 0.05
        elsif id == Gosu::KbI
            @angle_y = @angle_y - 0.05
        elsif id == Gosu::KbO
            @angle_z = @angle_z - 0.05

        elsif id == Gosu::KbF
            @camera_x = @camera_x - @speed
        elsif id == Gosu::KbT
            @camera_y = @camera_y - @speed
        elsif id == Gosu::KbH
            @camera_x = @camera_x + @speed
        elsif id == Gosu::KbG
            @camera_y = @camera_y + @speed
        elsif id == Gosu::KbV
            @camera_z = @camera_z - @speed
        elsif id == Gosu::KbB
            @camera_z = @camera_z + @speed
        end
    end

    def handle_key_press id, mouse_x, mouse_y
        if id == Gosu::KbA
            @center_x = @center_x - @speed
        elsif id == Gosu::KbD
            @center_x = @center_x + @speed
        elsif id == Gosu::KbW
            @center_y = @center_y - @speed
        elsif id == Gosu::KbS
            @center_y = @center_y + @speed
        elsif id == Gosu::KbSpace
            if @mode == MODE_ISOMETRIC 
                @mode = MODE_REAL_THREE_D 
            else 
                @mode = MODE_ISOMETRIC
            end
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
        elsif id == Gosu::KbF
            @camera_x = @camera_x - @speed
        elsif id == Gosu::KbT
            @camera_y = @camera_y - @speed
        elsif id == Gosu::KbH
            @camera_x = @camera_x + @speed
        elsif id == Gosu::KbG
            @camera_y = @camera_y + @speed
        elsif id == Gosu::KbV
            @camera_z = @camera_z - @speed
        elsif id == Gosu::KbB
            @camera_z = @camera_z + @speed
        elsif id == Gosu::KbR
            @mode = MODE_REAL_THREE_D 
            @scale = 0.001
            @angle_x = 0
            @angle_y = 0
            @angle_z = 0
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
