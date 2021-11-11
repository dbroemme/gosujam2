require 'gosu'
require 'wads'
#require 'rdia-games'
require_relative '../lib/rdia-games'

include Wads
include RdiaGames

WORLD_X_START = -1000
WORLD_X_END = 1000
WORLD_Z_START = -500
WORLD_Z_END = 9000

GAME_WIDTH = 1280
GAME_HEIGHT = 720


class CubeRender < RdiaGame
    def initialize
        super(GAME_WIDTH, GAME_HEIGHT, "Cube Render", CubeRenderDisplay.new)
        register_hold_down_key(Gosu::KbQ)    
        register_hold_down_key(Gosu::KbW)    
        register_hold_down_key(Gosu::KbE)    
        register_hold_down_key(Gosu::KbA)
        register_hold_down_key(Gosu::KbS)
        register_hold_down_key(Gosu::KbD)
        register_hold_down_key(Gosu::KbUp)
        register_hold_down_key(Gosu::KbDown)
    end 
end

class CubeRenderDisplay < Widget
    include Gosu

    def initialize
        super(0, 0, GAME_WIDTH, GAME_HEIGHT)
        disable_border

        @image_external_wall = Gosu::Image.new("./media/tile5.png")
        @image_tile_18 = Gosu::Image.new("./media/tile18.png")

        @engine = Engine.new(Point3D.new(0, 150,  800), # camera
                             Point3D.new(0,   0, -300)) # center

        @pause = false
        @speed = 10
        @continuous_movement = true

        # Our objects
        @cube = Cube.new(-300, 300, 100, COLOR_LIME)
        @engine.add_object(@cube)

        @grid = GridDisplay.new(0, 0, 100, 21, 95, {ARG_X_OFFSET => 10, ARG_Y_OFFSET => 5})
        instantiate_elements(@grid, @engine, File.readlines("./data/editor_board.txt")) 
        puts "World Map"
        puts "---------"
        (0..94).each do |y|
            str = ""
            (0..20).each do |x|
                str = "#{str}#{@world_map[x][y]}"
            end 
            puts str
        end

        puts "Raycast Map"
        puts "-----------"
        (0..20).each do |y|
            str = ""
            (0..94).each do |x|
                str = "#{str}#{@raycast_map[x][y]}"
            end 
            puts str
        end

        # Near and far walls
        x = -1000
        while x < 550
            far_wall = Wall.new(x, 8900, 500, 100, @image_external_wall, true)
            far_wall.set_visible_side(QUAD_S)
            @engine.add_object(far_wall)
            wall_behind_us = Wall.new(x, -500, 500, 100, @image_external_wall, true)
            wall_behind_us.set_visible_side(QUAD_N)
            @engine.add_object(wall_behind_us)
            x = x + 500
        end

        # Side walls
        z = -500
        while z < 8910
            left_wall = Wall.new(-1000, z, 100, 500, "./media/tile5.png", true)
            left_wall.set_visible_side(QUAD_W)
            @engine.add_object(left_wall)
            right_wall = Wall.new(1000, z, 100, 500, "./media/tile5.png", true)
            right_wall.set_visible_side(QUAD_E)
            @engine.add_object(right_wall)
            z = z + 500
        end

        x = -1000
        while x < 950
            z = -500
            while z < 8890
                @engine.add_object(FloorTile.new(x, z, 200))
                z = z + 200
            end 
            x = x + 200
        end

        @text_1 = Text.new(10, 10, "")
        add_child(@text_1)
        @text_2 = Text.new(10, 40, camera_text)
        add_child(@text_2)
        @text_3 = Text.new(10, 70, angle_text)
        add_child(@text_3)
        @text_4 = Text.new(10, 100, dir_text)
        add_child(@text_4)
        @text_5 = Text.new(10, 130, objects_text)
        add_child(@text_5)
        @text_6 = Text.new(10, 160, center_text)
        add_child(@text_6)
        @text_7 = Text.new(10, 190, cube_text)
        add_child(@text_7)
    end 

    def add_to_maps(x, y, val)
        #puts "Array #{x},#{y} -> #{val}"
        @world_map[x][y] = val
        @raycast_map[y][x] = val
    end 

    def instantiate_elements(grid, engine, dsl)
        @world_map = Array.new(grid.grid_width) do |x|
            Array.new(grid.grid_height) do |y|
                0
            end 
        end 
        @raycast_map = Array.new(grid.grid_height) do |y|
            Array.new(grid.grid_width) do |x|
                0
            end 
        end 
        grid.clear_tiles
        grid_y = 89
        grid_x = -10
        dsl.each do |line|
            index = 0
            while index < line.size
                char = line[index..index+1].strip
                img = nil
                # set_tile is already using the grid offsets, but here
                # we are directly creating a world map array so we need
                # to use the same offsets
                # So the Grid should probably do this, not here, but oh well
                array_grid_x = grid_x + grid.grid_x_offset
                array_grid_y = grid_y + grid.grid_y_offset
                #if char == "B"
                #    img = Brick.new(@blue_brick)
                if char == "5"
                    # ignore 5 because we manually constructed the wall using bigger chunks
                    add_to_maps(array_grid_x, array_grid_y, 5)
                    #img = Wall.new(grid_x * 100, grid_y * 100)
                elsif char == "18"
                    add_to_maps(array_grid_x, array_grid_y, 18)
                    img = Wall.new(grid_x * 100, grid_y * 100, 100, 100, @image_tile_18)
                end
                
                if not img.nil?
                    puts "Set tile #{grid_x},#{grid_y}  =  #{char}"
                    grid.set_tile(grid_x, grid_y, img)
                    engine.add_object(img)
                end

                grid_x = grid_x + 1
                index = index + 2
            end
            grid_x = -10
            grid_y = grid_y - 1
        end
    end 

    def render
        @engine.render
    end

    def handle_update update_count, mouse_x, mouse_y
        return if @pause
        @engine.modify_all_objects do |n|
            n.reset_visible_side
        end
        raycast_for_visibility

        @engine.calc_points
        @engine.debug_objects.each do |other_obj| 
            other_obj.calc_points(@engine)
        end

        @text_1.label = "Mouse: #{mouse_x}, #{mouse_y}"
        @text_2.label = camera_text
        @text_3.label = angle_text
        @text_4.label = dir_text
        number_of_invisible_objects = 0
        #@all_objects.each do |obj| 
        #    if not obj.visible
        #        number_of_invisible_objects = number_of_invisible_objects + 1
        #    end 
        #end
        @text_5.label = "#{objects_text}/#{number_of_invisible_objects}"
        @text_6.label = center_text
        @text_7.label = cube_text
    end

    def camera_text 
        "Camera: #{@engine.camera.x.round(2)}, #{@engine.camera.y.round(2)}, #{@engine.camera.z.round(2)}" 
    end 
    def center_text 
        "Center: #{@engine.center.x.round}, #{@engine.center.y.round}, #{@engine.center.z.round}" 
    end 
    def angle_text 
        "Angle: #{@engine.camera_angle.x.round(2)}, #{@engine.camera_angle.y.round(2)}, #{@engine.camera_angle.z.round(2)}"
    end 
    def dir_text 
        "Direction: #{@engine.direction_y.round(2)}, #{@engine.direction_x.round(2)}    quad: #{@engine.direction_quadrant}   grid: #{@grid.determine_grid_x(@engine.center.x)}, #{@grid.determine_grid_y(@engine.center.z)}"
    end 
    def objects_text 
        "Objects: #{@engine.all_objects.size} "
    end
    def cube_text 
        #if @dir_cube
        #    return "Dir Cube: #{@dir_cube.model_points[0].x.round(2)}, #{@dir_cube.model_points[0].y.round(2)}, #{@dir_cube.model_points[0].z.round(2)}"
        #end
        "" 
    end

    def tile_at_proposed_grid(proposed_x, proposed_y) 
        tile_x = @grid.determine_grid_x(proposed_x) + @grid.grid_x_offset
        tile_y = @grid.determine_grid_y(proposed_y) + @grid.grid_y_offset
        #puts "tile_x/y:  #{tile_x}, #{tile_y}"
        @world_map[tile_x][tile_y]
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
        elsif id == Gosu::KbUp
            @speed = @speed + 5
        elsif id == Gosu::KbDown
            @speed = @speed - 5
            if @speed < 5
                @speed = 5
            end
        elsif id == Gosu::KbC
            puts "------------"
            
            #cx = $camera.x
            #cz = -$camera.z
            cx = @engine.center.x
            cz = @engine.center.z

            size_square = 1000
            dx, dz = @engine.perpendicular_direction_counter_clockwise(@engine.direction_y, @engine.direction_x)
            #side_left = Point3D.new(cx + (dx * size_square), 0, cz + (dz * size_square))
            side_left = Point2D.new(cx + (dx * size_square), cz + (dz * size_square))

            dx, dz = @engine.perpendicular_direction_clockwise(@engine.direction_y, @engine.direction_x)
            #side_right = Point3D.new(cx + (dx * size_square), 0, cz + (dz * size_square))
            side_right = Point2D.new(cx + (dx * size_square), cz + (dz * size_square))

            # TODO run this out to the edges of the world
            #      how to do best do that?
            #      line intersection seems non-trivial
            #forward_left = Point3D.new(side_left.x + (@dir_y * size_square), 0, side_left.z + (@dir_x * size_square))
            #forward_right = Point3D.new(side_right.x + (@dir_y * size_square), 0, side_right.z + (@dir_x * size_square))
            forward_left = Point2D.new(side_left.x + (@engine.direction_y * size_square), side_left.y + (@engine.direction_x * size_square))
            forward_right = Point2D.new(side_right.x + (@engine.direction_y * size_square), side_right.y + (@engine.direction_x * size_square))
            
            puts "Find intersecting lines with worlds edge"
            bottom_line = Line2D.new(side_left, side_right)
            world_left_edge = Line2D.new(Point2D.new(WORLD_X_START, WORLD_Z_START), side_right)



            vb = [side_left, forward_left, forward_right, side_right]

            puts "The visibility polygon is #{vb}"

            pip = PointInsidePolygon.new
            @engine.all_objects.each do |an_obj|
                if an_obj.is_external or an_obj.is_a? FloorTile 
                    # skip 
                else 
                    point = Point2D.new(an_obj.model_points[0].x, an_obj.model_points[0].z)
                    
                    if pip.isInside(vb, 4, point)
                        # do nothing
                        puts "Inside #{an_obj}"
                        an_obj.color = COLOR_AQUA
                    else
                        puts "Setting #{an_obj} to invisible"
                        an_obj.color = COLOR_LIME
                    end
                end 
            end 

            @engine.debug_objects = []
            @engine.add_debug_object Line3D.new(Point3D.new(vb[0].x, 0, vb[0].y), Point3D.new(vb[1].x, 0, vb[1].y), COLOR_RED)
            @engine.add_debug_object Line3D.new(Point3D.new(vb[1].x, 0, vb[1].y), Point3D.new(vb[2].x, 0, vb[2].y), COLOR_RED)
            @engine.add_debug_object Line3D.new(Point3D.new(vb[2].x, 0, vb[2].y), Point3D.new(vb[3].x, 0, vb[3].y), COLOR_RED)
            @engine.add_debug_object Line3D.new(Point3D.new(vb[3].x, 0, vb[3].y), Point3D.new(vb[0].x, 0, vb[0].y), COLOR_RED)
        
        
        elsif id == Gosu::KbX 
            puts "------------"
            puts "Lets raycast"
            ray_line = raycast(640) 
            puts ray_line
            slope = ray_line.slope 
            puts slope
            qfs = ray_line.quad_from_slope
            puts "Quad: #{qfs}"
        
        
        
        elsif id == Gosu::KbR
            @engine.modify_all_objects do |n|
                if n.is_external 
                    # do nothing
                elsif n.is_a? Cube 
                    # do nothing
                elsif n.is_a? FloorTile 
                    # do nothing
                else
                    n.set_visible_side(QUAD_ALL)
                    n.color = COLOR_AQUA 
                end
            end
        elsif id == Gosu::KbV 
            @pause = !@pause
        end
    end

    def visibility_polygon
        # TODO put the code back here
    end 

    def raycast_for_visibility
        (0..1279).each do |x|
            ray_data = raycast(x) 
            if ray_data.at_ray != 0
                # Get the tile at this spot
                tile = @grid.get_tile(ray_data.map_y, ray_data.map_x)
                if tile
                    quad = ray_data.quad_from_slope
                    tile.set_visible_side(quad)
                end
            end
        end
    end

    def raycast(x, plane_x = 0, plane_y = 0.66) 
        #tile_x = @grid.determine_grid_x($camera.x)   # If you really see what is visible, use the camera
        #tile_y = @grid.determine_grid_y($camera.z)
        tile_x = @grid.determine_grid_x(@engine.center.x)
        tile_y = @grid.determine_grid_y(@engine.center.z)
        adj_tile_x = tile_x + @grid.grid_x_offset
        adj_tile_y = tile_y + @grid.grid_y_offset
        drawStart, drawEnd, mapX, mapY, side, orig_map_x, orig_map_y = @engine.ray(x, adj_tile_y, adj_tile_x, @engine.direction_x, @engine.direction_y, plane_x, plane_y, @raycast_map, GAME_WIDTH)
        adj_map_x = mapX - @grid.grid_y_offset   # The raycast map is set the other way
        adj_map_y = mapY - @grid.grid_x_offset
        adj_orig_map_x = orig_map_x - @grid.grid_y_offset
        adj_orig_map_y = orig_map_y - @grid.grid_x_offset

        at_ray = @raycast_map[mapX][mapY]
        if at_ray == 5
            color_to_use = COLOR_AQUA
            if side == 1
                color_to_use = COLOR_BLUE
            end
        elsif at_ray == 18
            color_to_use = COLOR_LIME
            if side == 1
                color_to_use = COLOR_PEACH
            end
        end
        
        RayCastData.new(x, tile_x, tile_y, adj_map_x, adj_map_y, at_ray, side, drawStart, drawEnd, color_to_use, adj_orig_map_x, adj_orig_map_y)
    end

    def handle_movement id, mouse_x, mouse_y 
        if id == Gosu::KbQ
            # Lateral movement
            @engine.camera.x = @engine.camera.x + @speed
            @engine.center.x = @engine.center.x - @speed
        elsif id == Gosu::KbE
            # Lateral movement
            @engine.camera.x = @engine.camera.x - @speed
            @engine.center.x = @engine.center.x + @speed
        elsif id == Gosu::KbW
            # Primary movement keys (WASD)
            movement_x = @engine.direction_y * @speed
            movement_z = @engine.direction_x * @speed

            proposed_x = @engine.center.x + movement_x
            proposed_z = @engine.center.z + movement_z
            proposed = tile_at_proposed_grid(proposed_x, proposed_z)
            if proposed == 0 
                @engine.camera.x = @engine.camera.x - movement_x
                @engine.center.x = proposed_x

                @engine.camera.z = @engine.camera.z - movement_z
                @engine.center.z = proposed_z
            end

        elsif id == Gosu::KbS
            movement_x = @engine.direction_y * @speed
            movement_z = @engine.direction_x * @speed

            proposed_x = @engine.center.x - movement_x
            proposed_z = @engine.center.z - movement_z
            proposed = tile_at_proposed_grid(proposed_x, proposed_z)
            if proposed == 0 
                @engine.camera.x = @engine.camera.x + movement_x
                @engine.center.x = proposed_x

                @engine.camera.z = @engine.camera.z + movement_z
                @engine.center.z = proposed_z
            end

        elsif id == Gosu::KbD
            @engine.camera_angle.y = @engine.camera_angle.y + 0.05
            @engine.direction_x = Math.cos(@engine.camera_angle.y)
            @engine.direction_y = Math.sin(@engine.camera_angle.y)
            @engine.determine_directional_quadrant
        elsif id == Gosu::KbA
            @engine.camera_angle.y = @engine.camera_angle.y - 0.05
            @engine.direction_x = Math.cos(@engine.camera_angle.y)
            @engine.direction_y = Math.sin(@engine.camera_angle.y)
            @engine.determine_directional_quadrant
        end
    end

    def handle_key_up id, mouse_x, mouse_y
        # nothing to do
    end

    def handle_mouse_down mouse_x, mouse_y
        @mouse_dragging = true
    end

    def handle_mouse_up mouse_x, mouse_y
        @mouse_dragging = false
    end
end

CubeRender.new.show
