require 'gosu'
#require 'wads'
require_relative '../../ruby-wads/lib/wads'
#require 'rdia-games'
require_relative '../lib/rdia-games'

include Wads
include RdiaGames

GAME_WIDTH = 800
GAME_HEIGHT = 700
GAME_START_X = 10
GAME_START_Y = 10

class BricksGame < RdiaGame
    def initialize
        super(GAME_WIDTH, GAME_HEIGHT, "Ruby Bricks", BricksDisplay.new)
        register_hold_down_key(Gosu::KbD)    # Move left
        register_hold_down_key(Gosu::KbF)    # Move right
    end 
end

class BricksDisplay < Widget
    def initialize
        super(0, 0, GAME_WIDTH, GAME_HEIGHT)
        set_layout(LAYOUT_HEADER_CONTENT)
        #set_theme(WadsDarkRedBrownTheme.new)
        disable_border
        add_panel(SECTION_NORTH).get_layout.add_text("Ruby Bricks",
                                                     { ARG_TEXT_ALIGN => TEXT_ALIGN_CENTER,
                                                       ARG_USE_LARGE_FONT => true})

        @tileset = Gosu::Image.load_tiles("media/basictiles.png", 16, 16, tileable: true)
        puts "Number of tiles: #{@tileset.size}"
        @blue_brick = @tileset[1]   # the brick with an empty pixel on the left and right, so there is a gap
        @red_wall = @tileset[7]
        @yellow_dot = @tileset[18]
        @green_dot = @tileset[19]
        @player_tile = @tileset[81]

        @player = Player.new(@player_tile, 6, 1)   # 6 tiles wide, so 6 * 16 = 06
        @player.set_absolute_position(400, 563)
        add_child(@player)

        @ball = Ball.new(442, 550)
        @ball.start_move_in_direction(DEG_90)
        @ball.speed = 3
        add_child(@ball)

        @grid = GridDisplay.new(0, 100, 16, 50, 31)
        #@grid.disable_border
        instantiate_elements(File.readlines("./data/board.txt"))
        add_child(@grid)
    end 

    def handle_update update_count, mouse_x, mouse_y
        @ball.move(@grid) do |widgets|
            # Determine which widget we interacted with and what to do
            if widgets.empty?
                raise "Error occured, we should not have an empty widget list for interactions"
            elsif widgets.size == 1
                w = widgets[0]
            else 
                # Choose the widget with the shortest distance from the center of the ball
                closest_widget = nil 
                closest_distance = 100   # some large number
                widgets.each do |candidate_widget| 
                    d = @ball.distance_between_center_mass(candidate_widget)
                    debug("Comparing #{d} with #{closest_distance}")
                    if d < closest_distance
                        closest_distance = d 
                        closest_widget = candidate_widget 
                    end 
                end 
                w = closest_widget
            end
            puts "Interacting with widget #{w}. Reaction is #{w.interaction_result}"
            if w.interaction_result.include? RDIA_REACT_STOP 
                @ball.stop_move
            end
            if w.interaction_result.include? RDIA_REACT_BOUNCE 
                if @ball.center_x >= w.x and @ball.center_x <= w.right_edge
                    @ball.bounce_y
                elsif @ball.center_y >= w.y and @ball.center_y <= w.bottom_edge
                    @ball.bounce_x
                else 
                    info("wall doesnt know how to bounce ball. #{w.x}  #{@ball.center_x}  #{w.right_edge}")
                    quad = @ball.relative_quad(w)
                    info("Going to bounce off relative quad #{quad}")
                    gdd = nil
                    if quad == QUAD_NW 
                        gdd = @ball.x_or_y_dimension_greater_distance(w.x, w.y)        
                    elsif quad == QUAD_NE
                        gdd = @ball.x_or_y_dimension_greater_distance(w.right_edge, w.y)
                    elsif quad == QUAD_SE
                        gdd = @ball.x_or_y_dimension_greater_distance(w.right_edge, w.bottom_edge)
                    elsif quad == QUAD_SW
                        gdd = @ball.x_or_y_dimension_greater_distance(w.x, w.bottom_edge)
                    else 
                        info("ERROR adjust for ball accel from quad #{quad}")
                    end

                    if gdd == X_DIM
                        @ball.bounce_x
                    else 
                        # Right now, if it is not defined, one of the diagonal quadrants
                        # we are bouncing on the y dimension.
                        # Not technically accurate, but probably good enough for now
                        @ball.bounce_y
                    end
                end
            end
            if w.interaction_result.include? RDIA_REACT_CONSUME
                @grid.remove_tile_at_absolute(w.x + 1, w.y + 1)
            end
            if w.interaction_result.include? RDIA_REACT_GOAL
                # TODO end this round
            end
        end
    end

    def handle_key_held_down id, mouse_x, mouse_y
        if id == Gosu::KbD 
            @player.move_left(@grid)
        elsif id == Gosu::KbF
            @player.move_right(@grid)
        end
    end

    def handle_key_press id, mouse_x, mouse_y
        if id == Gosu::KbD 
            @player.start_move_left 
        elsif id == Gosu::KbF
            @player.start_move_right 
        end
    end

    # Takes an array of strings that represents the board
    def instantiate_elements(dsl)         
        @grid.clear_tiles
        grid_y = 0
        grid_x = 0
        dsl.each do |line|
            index = 0
            while index < line.size
                char = line[index]
                #puts "#{grid_x},#{grid_y}  =  #{char}"
                img = nil
                if char == "B"
                    img = Brick.new(@blue_brick)
                elsif char == "W"
                    img = Wall.new(@red_wall)
                elsif char == "Y"
                    img = Dot.new(@yellow_dot)
                elsif char == "G"
                    img = Dot.new(@green_dot)
                #elsif char == "T"
                #    @elements << TriangleBrick.new(grid_x_to_pixel(grid_x), grid_y_to_pixel(grid_y), QUAD_NW)
                #elsif char == "V"
                #    @elements << TriangleBrick.new(grid_x_to_pixel(grid_x), grid_y_to_pixel(grid_y), QUAD_NE)
                #elsif char == "X"
                #    @elements << TriangleBrick.new(grid_x_to_pixel(grid_x), grid_y_to_pixel(grid_y), QUAD_SW)
                #elsif char == "Z"
                #    @elements << TriangleBrick.new(grid_x_to_pixel(grid_x), grid_y_to_pixel(grid_y), QUAD_SE)
                #elsif char == "R"
                #    @elements << RedDot.new(grid_x_to_pixel(grid_x), grid_y_to_pixel(grid_y))
                end
                
                if img.nil?
                    # nothing to do
                else
                    @grid.set_tile(grid_x, grid_y, img)
                end

                grid_x = grid_x + 1
                index = index + 1
            end
            grid_x = 0
            grid_y = grid_y + 1
        end
    end 
end

class Wall < GameObject
    def initialize(image)
        super(image)
        @can_move = false
    end

    def interaction_results
        [RDIA_REACT_BOUNCE]
    end
end

class Brick < GameObject
    def initialize(image)
        super(image)
        @can_move = false
    end

    def interaction_result
        [RDIA_REACT_BOUNCE, RDIA_REACT_CONSUME]
    end
end

class Dot < GameObject
    def initialize(image)
        super(image)
        @can_move = false
    end

    def interaction_result
        [RDIA_REACT_CONSUME]
    end
end

BricksGame.new.show
