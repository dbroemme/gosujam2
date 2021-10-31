require 'gosu'
require 'wads'
#require 'rdia-games'
require_relative '../lib/rdia-games'

include Wads
include RdiaGames

GAME_WIDTH = 1280
GAME_HEIGHT = 720

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
        super(GAME_WIDTH, GAME_HEIGHT, "TileEditor", CubeRenderDisplay.new)
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

    end 
end

class CubeRenderDisplay < Widget
    include Gosu

    def initialize
        super(0, 0, GAME_WIDTH, GAME_HEIGHT)
        disable_border

        @center_x = 600   # this is what the buttons will cause to move
        @center_y = 300
        @center_z = 100
        @radius = 100
        @speed = 5
        @rotation_angle = 0.0
        @draw_at_angle = false

        # center point is the pivot point
        # XD = X(N)-PIVX
        # YD = Y(N)-PIVY

        # XROTOFFSET = XD*Cos{ANGLEZ} - YD*Sin{ANGLEZ} - XD
        # YROTOFFSET = XD*Sin{ANGLEZ} + YD*Cos{ANGLEZ} - YD

        

        @current_mouse_text = Text.new(10, 700, "0, 0")
        add_child(@current_mouse_text)

        @square_points = [] 
        @square_points << Point.new(@center_x - @radius, @center_y - @radius)
        @square_points << Point.new(@center_x + @radius, @center_y - @radius)
        @square_points << Point.new(@center_x + @radius, @center_y + @radius)
        @square_points << Point.new(@center_x - @radius, @center_y + @radius)

        @three_d_points = [] 

        @a = ThreeDPoint.new(@center_x - @radius, @center_y - @radius, @center_z + 100)
        @b = ThreeDPoint.new(@center_x + @radius, @center_y - @radius, @center_z + 100)
        @c = ThreeDPoint.new(@center_x + @radius, @center_y + @radius, @center_z + 100)
        @d = ThreeDPoint.new(@center_x - @radius, @center_y + @radius, @center_z + 100)
        @e = ThreeDPoint.new(@center_x - @radius, @center_y - @radius, @center_z - 100)
        @f = ThreeDPoint.new(@center_x + @radius, @center_y - @radius, @center_z - 100)
        @g = ThreeDPoint.new(@center_x + @radius, @center_y + @radius, @center_z - 100)
        @h = ThreeDPoint.new(@center_x - @radius, @center_y + @radius, @center_z - 100)
        @three_d_points << @a
        @three_d_points << @b 
        @three_d_points << @c 
        @three_d_points << @d 
        @three_d_points << @e 
        @three_d_points << @f 
        @three_d_points << @g 
        @three_d_points << @h

        #add_text("Current Tile:", 900, 630)
        #add_button("Use Eraser", 940, 680, 120) do
        #    if @use_eraser 
        #        @use_eraser = false 
        #    else 
        #        @use_eraser = true
        #        WidgetResult.new(false)
        #    end
        #end
    end 

    # This uses algorithm described in https://www.skytopia.com/project/cube/cube.html
    def rotate_square
        @new_square_points = [] 
        (0..3).each do |n|
            cube_point = @square_points[n]
            # XD = X(N)-PIVX
            # YD = Y(N)-PIVY
            xd = cube_point.x - @center_x
            yd = cube_point.y - @center_y
            # XROTOFFSET = XD*Cos{ANGLEZ} - YD*Sin{ANGLEZ} - XD
            # YROTOFFSET = XD*Sin{ANGLEZ} + YD*Cos{ANGLEZ} - YD
            x_rot_offset = (xd * Math.cos(@rotation_angle)) - (yd * Math.sin(@rotation_angle)) - xd
            y_rot_offset = (xd * Math.sin(@rotation_angle)) + (yd * Math.cos(@rotation_angle)) - yd
            @new_square_points << Point.new(cube_point.x + x_rot_offset, cube_point.y + y_rot_offset)
        end
        @square_points = @new_square_points
    end

    def rotate_cube(angle_x, angle_y, angle_z)
        @new_3d_points = [] 
        @three_d_points.each do |three_d_point|
            # XD = X(N)-PIVX
            # YD = Y(N)-PIVY
            # ZD = Z(N)-PIVZ
            xd = three_d_point.x - @center_x
            yd = three_d_point.y - @center_y
            zd = three_d_point.z - @center_z

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

            @new_3d_points << ThreeDPoint.new(three_d_point.x + x_rot_offset,
                                              three_d_point.y + y_rot_offset,
                                              three_d_point.z + z_rot_offset)
        end
        @a = @new_3d_points[0]
        @b = @new_3d_points[1]
        @c = @new_3d_points[2]
        @d = @new_3d_points[3]
        @e = @new_3d_points[4]
        @f = @new_3d_points[5]
        @g = @new_3d_points[6]
        @h = @new_3d_points[7]
        @three_d_points = @new_3d_points
    end

    def render 
        #draw_square(@square_points)
        draw_cube
    end 

    #
    # 3D Cube
    #
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

    def handle_update update_count, mouse_x, mouse_y
        @current_mouse_text.label = "#{mouse_x}, #{mouse_y}"
    end

    def move_left 
        adjust_x(-@speed)
        @center_x = @center_x - @speed
        three_d_adjust_x(-@speed)
    end 
    def move_right 
        adjust_x(@speed)
        @center_x = @center_x + @speed
        three_d_adjust_x(@speed)
    end 
    def move_up 
        adjust_y(-@speed)
        @center_y = @center_y - @speed
        three_d_adjust_y(-@speed)
    end 
    def move_down
        adjust_y(@speed)
        @center_y = @center_y + @speed
        three_d_adjust_y(@speed)
    end 

    def adjust_x(amount)
        (0..3).each do |n|
            cube_point = @square_points[n]
            cube_point.x = cube_point.x + amount 
        end
    end
    def adjust_y(amount)
        (0..3).each do |n|
            cube_point = @square_points[n]
            cube_point.y = cube_point.y + amount 
        end
    end

    def three_d_adjust_x(amount)
        @three_d_points.each do |three_d_point|
            three_d_point.x = three_d_point.x + amount 
        end
    end
    def three_d_adjust_y(amount)
        @three_d_points.each do |three_d_point|
            three_d_point.y = three_d_point.y + amount 
        end
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
        elsif id == Gosu::KbP or id == Gosu::KbO
            rotate_square
            rotate_cube(0.05, 0, 0.05)
        elsif id == Gosu::KbJ
            rotate_cube(0.05, 0, 0)
        elsif id == Gosu::KbK
            rotate_cube(0, 0.05, 0)
        elsif id == Gosu::KbL
            rotate_cube(0, 0, 0.05)
        elsif id == Gosu::KbU
            rotate_cube(-0.05, 0, 0)
        elsif id == Gosu::KbI
            rotate_cube(0, -0.05, 0)
        elsif id == Gosu::KbO
            rotate_cube(0, 0, -0.05)
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
        elsif id == Gosu::KbP
            @rotation_angle = 0.05
        elsif id == Gosu::KbO
            @rotation_angle = -0.05
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
