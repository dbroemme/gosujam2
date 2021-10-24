require 'gosu'
require 'wads'
#require 'rdia-games'
require_relative '../lib/rdia-games'

include Wads
include RdiaGames

GAME_WIDTH = 800
GAME_HEIGHT = 700

class BricksGame < RdiaGame
    def initialize
        super(GAME_WIDTH, GAME_HEIGHT, "Ruby Bricks", BricksDisplay.new)
        register_hold_down_key(Gosu::KbW)
        register_hold_down_key(Gosu::KbA)
        register_hold_down_key(Gosu::KbS)
        register_hold_down_key(Gosu::KbD)
    end 
end

class BricksDisplay < Widget
    def initialize
        super(0, 0, GAME_WIDTH, GAME_HEIGHT)
        set_layout(LAYOUT_HEADER_CONTENT)
        disable_border
        @game_mode = RDIA_MODE_START
        @score = 0
        @level = 1
        @lives = 3
        @fire_level = 36
        @launch_font = Gosu::Font.new(56, {:name => File.join(File.dirname(File.dirname(__FILE__)), 'media', "armalite_rifle.ttf")})

        header_panel = add_panel(SECTION_NORTH)
        header_panel.get_layout.add_text("Ruby Bricks",
                                         { ARG_TEXT_ALIGN => TEXT_ALIGN_CENTER,
                                           ARG_USE_LARGE_FONT => true})
        subheader_panel = header_panel.get_layout.add_vertical_panel({ARG_LAYOUT => LAYOUT_EAST_WEST,
                                                                      ARG_DESIRED_WIDTH => GAME_WIDTH})
        subheader_panel.disable_border
        west_panel = subheader_panel.add_panel(SECTION_WEST)
        west_panel.get_layout.add_text("  Score")
        @score_text = west_panel.get_layout.add_text("  #{@score}")
        
        east_panel = subheader_panel.add_panel(SECTION_EAST)
        east_panel.get_layout.add_text("Level  ", {ARG_TEXT_ALIGN => TEXT_ALIGN_RIGHT})
        @level_text = east_panel.get_layout.add_text("#{@level}  ",
                                                     {ARG_TEXT_ALIGN => TEXT_ALIGN_RIGHT})
        
        @progress_bar = ProgressBar.new(200, 70, 400, 10, {ARG_DELAY => 6,
                                                           ARG_PROGRESS_AMOUNT => 0.01})
        add_child(@progress_bar)

        pause_game

        add_overlay(GameMessageOverlay.new("Welcome to Ruby Bricks", "welcome"))

        @tileset = Gosu::Image.load_tiles("media/basictiles.png", 16, 16, tileable: true)
        @blue_brick = @tileset[1]   # the brick with an empty pixel on the left and right, so there is a gap
        @red_wall = @tileset[7]
        @yellow_dot = @tileset[18]
        @green_dot = @tileset[19]
        @player_tile = @tileset[81]
        @goal_tile = @tileset[64]
        @fire_transition_tile = @tileset[66]
        @tree_tile = @tileset[38]
        @torch_tile = @tileset[59]
        @diagonal_tileset = Gosu::Image.load_tiles("media/diagonaltiles.png", 16, 16, tileable: true)
        @red_wall_se = @diagonal_tileset[0]
        @red_wall_sw = @diagonal_tileset[7]
        @red_wall_nw = @diagonal_tileset[13]
        @red_wall_ne = @diagonal_tileset[10]

        @player = Player.new(@player_tile, 6, 1)   # 6 tiles wide, so 6 * 16 = 06
        add_child(@player)

        @ball = Ball.new(0, 0)
        @ball.start_move_in_direction(DEG_90 - 0.2)
        add_child(@ball)

        @aim_radians = DEG_90 - 0.02
        @aim_speed = 6

        @grid = GridDisplay.new(0, 100, 16, 50, 38)
        add_child(@grid)
        start_level
    end 

    def pause_game 
        if @pause 
            return 
        end 
        @pause = true 
        @progress_bar.stop
    end 

    def restart_game 
        @pause = false 
        @progress_bar.start
    end 

    def more_levels_left
        content_file_name = File.join(File.dirname(File.dirname(__FILE__)), 'data', "messages_#{@level}.txt")
        File.exist?(content_file_name)
    end

    def start_level
        level_config_file_name = File.join(File.dirname(File.dirname(__FILE__)), 'data', "level#{@level}.txt")
        level_config = eval(File.open(level_config_file_name) {|f| f.read })
        @player.set_absolute_position(level_config[:player_x], level_config[:player_y])
        @ball.set_absolute_position(level_config[:ball_x], level_config[:ball_y])
        @ball.start_move_in_direction(DEG_90 - 0.2)

        if @play_again_button 
            remove_child(@play_again_button)
        end
        @progress_bar.stop
        @progress_bar.reset
        @grid.clear_tiles
        @level_text.label = "#{@level}  "
        @fire_level = 36
        file_name = "./data/board#{@level}.txt"
        if File.exist?(file_name)
            instantiate_elements(File.readlines(file_name))
        else 
            # There are no more levels
            @game_mode = RDIA_MODE_END
        end
    end 

    def handle_update update_count, mouse_x, mouse_y
        if @progress_bar.is_done
            @fire_level = @fire_level - 1
            (1..44).each do |n|
                #info("Setting tile #{n}, #{@fire_level} to fire tile")
                @grid.set_tile(n, @fire_level, OutOfBounds.new(@fire_transition_tile))
            end
            @player.y = @player.y - 16
            @progress_bar.reset
            @progress_bar.start
        end

        if @launch_countdown
            @launch_countdown = @launch_countdown -1
            if @launch_countdown < 0
                @launch_countdown = nil
                @launch_text = nil
                launch_ball
            elsif @launch_countdown < 60
                @launch_text = "1"
            elsif @launch_countdown < 120
                @launch_text = "2"
            elsif @launch_countdown < 180
                @launch_text = "3"
            end
        else 
            @launch_text = nil 
        end 

        return unless @ball.can_move
        return unless @ball.speed > 0
        return if @pause
        # Speed is implemented by moving multiple times.
        # Each time, we check for interactions with other game objects
        speed_to_use = @ball.speed
        if @ball.speed < 1
            speed_to_use = 1
        end
        loop_count = 0
        speed_to_use.round.times do 
            proposed_next_x, proposed_next_y = @ball.proposed_move
            widgets_at_proposed_spot = @grid.proposed_widget_at(@ball, proposed_next_x, proposed_next_y)
            if widgets_at_proposed_spot.empty?
                if @ball.overlaps_with_proposed(proposed_next_x, proposed_next_y, @player)
                    info("We hit the player!")
                    bounce_off_player(proposed_next_x, proposed_next_y)
                else
                    @ball.set_absolute_position(proposed_next_x, proposed_next_y)
                end
            else 
                #info("Found candidate widgets to interact")
                if interact_with_widgets(widgets_at_proposed_spot, update_count)
                    @ball.set_absolute_position(proposed_next_x, proposed_next_y) 
                end
            end
            #@ball.log_debug(update_count, loop_count)
            loop_count = loop_count + 1
        end
    end

    def bounce_off_player(proposed_next_x, proposed_next_y)
        in_radians = @ball.direction
        cx = @ball.center_x 
        scale_length = @player.width + @ball.width
        impact_on_scale = ((@player.right_edge + (@ball.width / 2)) - cx) + 0.25
        pct = impact_on_scale.to_f / scale_length.to_f
        @ball.direction = (pct * Math::PI)
        info("Scale length: #{scale_length}  Impact on Scale: #{impact_on_scale.round}  Pct: #{pct.round(2)}  rad: #{@ball.direction.round(2)}  speed: #{@ball.speed}")
        info("#{impact_on_scale.round}/#{scale_length}:  #{pct.round(2)}%")
        @ball.last_element_bounce = @player.object_id
    end

    def interact_with_widgets(widgets, update_count)
        if widgets.size == 1
            w = widgets[0]
            if w.object_id == @ball.last_element_bounce
                # Don't bounce off the same element twice
                w = nil 
            end
        else 
            # Choose the widget with the shortest distance from the center of the ball
            closest_widget = nil 
            closest_distance = 100   # some large number
            widgets.each do |candidate_widget| 
                d = @ball.distance_between_center_mass(candidate_widget)
                debug("Comparing #{d} with #{closest_distance}. Candidate #{candidate_widget.object_id}  last bounce: #{@ball.last_element_bounce}")
                if d < closest_distance and candidate_widget.object_id != @ball.last_element_bounce
                    closest_distance = d 
                    closest_widget = candidate_widget 
                end 
            end 
            w = closest_widget
        end
        if w.nil?
            return true
        end
        #puts "Reaction #{w.interaction_results} with widget #{w}"
        @ball.last_element_bounce = w.object_id
        if w.interaction_results.include? RDIA_REACT_STOP 
            @ball.stop_move
        end
        if w.interaction_results.include? RDIA_REACT_LOSE 
            if @pause 
                info("Skipping the lose interaction because we are paused")
            else
                pause_game
                @lives = @lives - 1
                if @lives == 0
                    @game_mode = RDIA_MODE_END
                    add_overlay(GameMessageOverlay.new("Sorry, you lost", "lose"))
                    instantiate_elements(File.readlines("./data/board_end.txt"))
                    @play_again_button = add_button("Play again", 300, 300, 200) do
                        @level = 1
                        @lives = 3
                        @fire_level = 36
                        start_level
                    end
                else 
                    add_overlay(GameMessageOverlay.new("Oh no! Your ball was lost.", "tryagain"))
                    @game_mode = RDIA_MODE_RESTART 
                end
            end
        end
        if w.interaction_results.include? RDIA_REACT_BOUNCE 
            square_bounce(w)
        elsif w.interaction_results.include? RDIA_REACT_BOUNCE_DIAGONAL
            diagonal_bounce(w)
        end
        if w.interaction_results.include? RDIA_REACT_CONSUME
            @grid.remove_tile_at_absolute(w.x + 1, w.y + 1)
        end
        if w.interaction_results.include? RDIA_REACT_SCORE
            @score = @score + w.score
            @score_text.label = "  #{@score}"
        end
        if w.interaction_results.include? RDIA_REACT_GOAL
            if @pause 
                # We already hit a goal widget, so don't need to do it again
            else 
                pause_game
                info("Bumping up the level #{@level}")
                @level = @level + 1
                #start_level
                if more_levels_left
                    info("There are more levels left after #{@level}")
                    @game_mode = RDIA_MODE_RESTART
                    add_overlay(GameMessageOverlay.new("Congrats! You completed level #{@level - 1}.", "#{@level}"))
                else
                    info("No more levels left after #{@level}")
                    @game_mode = RDIA_MODE_END
                    add_overlay(GameMessageOverlay.new("You won!", "win"))
                end
            end
        end
        true
    end

    def square_bounce(w)
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

    def diagonal_bounce(w)
        if @ball.direction > DEG_360 
            raise "ERROR ball radians are above double pi #{@ball.direction}. Cannot adjust triangle accelerations"
        end

        axis = AXIS_VALUES[w.orientation]
        if @ball.will_hit_axis(axis)
            puts "Triangle bounce"
            @ball.bounce(axis)
        else 
            puts "Square bounce"
            square_bounce(w)
        end
    end 

    def render
        if @ball.is_stopped and @game_mode == RDIA_MODE_PREPARE 
            # Draw the aim directional element
            aim_size = 6
            aim_colors = [Gosu::Color.argb(0xffDAA6A4), Gosu::Color.argb(0xffDAC1A4),
                          Gosu::Color.argb(0xffD8DAA4), Gosu::Color.argb(0xffBDDAA4),
                          Gosu::Color.argb(0xffA4DAA6)]
            proposed_speed = 12
            (0..4).each do |n| 
                aim_point = @ball.calc_aim_point(@aim_radians, proposed_speed)
                Gosu::draw_rect(aim_point.x - (aim_size / 2), aim_point.y - (aim_size / 2), aim_size, aim_size, aim_colors[n], 20)
                proposed_speed = proposed_speed + (@aim_speed * 1.5)
            end
        end

        if @launch_text
            @launch_font.draw_text(@launch_text, 380, 400, 20, 1, 1, COLOR_LIGHT_GRAY)
        end
    end

    def handle_key_held_down id, mouse_x, mouse_y
        if @game_mode == RDIA_MODE_PLAY
            if id == Gosu::KbA or id == Gosu::KbS
                @player.move_left(@grid)
            elsif id == Gosu::KbD
                @player.move_right(@grid)
            end
        elsif @game_mode == RDIA_MODE_PREPARE 
            if id == Gosu::KbW
                @aim_speed = @aim_speed + 0.25
                if @aim_speed > 12
                    @aim_speed = 12
                end
            elsif id == Gosu::KbS
                @aim_speed = @aim_speed - 0.25
                if @aim_speed < 3
                    @aim_speed = 3
                end
            elsif id == Gosu::KbA
                @aim_radians = @aim_radians + 0.01
            elsif id == Gosu::KbD
                @aim_radians = @aim_radians - 0.01
            end
        end
    end

    def handle_key_press id, mouse_x, mouse_y
        if @game_mode == RDIA_MODE_PLAY
            if id == Gosu::KbA or id == Gosu::KbS
                @player.start_move_left 
            elsif id == Gosu::KbD
                @player.start_move_right 
            elsif id == Gosu::KbSpace
                @ball.speed_up
            elsif id == Gosu::KbQ
                if @pause 
                    restart_game 
                else 
                    pause_game 
                end
            end
        elsif @game_mode == RDIA_MODE_PREPARE 
            if id == Gosu::KbW
                @aim_speed = @aim_speed + 1
                if @aim_speed > 12
                    @aim_speed = 12
                end
            elsif id == Gosu::KbS
                @aim_speed = @aim_speed - 1
                if @aim_speed < 3
                    @aim_speed = 3
                end
            elsif id == Gosu::KbA
                @aim_radians = @aim_radians + 0.01
            elsif id == Gosu::KbD
                @aim_radians = @aim_radians - 0.01
            elsif id == Gosu::KbSpace
                launch_ball
            end
        end
    end

    def launch_ball 
        @ball.direction = @aim_radians 
        @ball.speed = @aim_speed 
        restart_game 
        @game_mode = RDIA_MODE_PLAY
        @progress_bar.start
    end

    def intercept_widget_event(result)
        info("We intercepted the event #{result.inspect}")
        info("Game mode is #{@game_mode}. The overlay widget is #{@overlay_widget}")
        if result.close_widget 
            if @game_mode == RDIA_MODE_START
                @game_mode = RDIA_MODE_PREPARE
                @launch_countdown = 240    
            elsif @game_mode == RDIA_MODE_RESTART
                @game_mode = RDIA_MODE_PREPARE
                @launch_countdown = 240    
                start_level
            elsif @game_mode == RDIA_MODE_END
                @game_mode = RDIA_MODE_START
            end
        end
        result
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
                elsif char == "F"
                    img = OutOfBounds.new(@fire_transition_tile)
                elsif char == "T"
                    img = DiagonalWall.new(@red_wall_nw, QUAD_NW)
                elsif char == "V"
                    img = DiagonalWall.new(@red_wall_ne, QUAD_NE)
                elsif char == "X"
                    img = DiagonalWall.new(@red_wall_sw, QUAD_SW)
                elsif char == "Z"
                    img = DiagonalWall.new(@red_wall_se, QUAD_SE)
                elsif char == "E"
                    img = GoalArea.new(@goal_tile)
                elsif char == "N"
                    img = BackgroundArea.new(@tree_tile)
                elsif char == "D"
                    img = BackgroundArea.new(@torch_tile)
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

class DiagonalWall < GameObject
    attr_accessor :orientation
    def initialize(image, orientation)
        super(image)
        @orientation = orientation
    end

    def interaction_results
        [RDIA_REACT_BOUNCE_DIAGONAL]
    end

    def comparison_corner_point(ball)
        if @orientation == QUAD_SE
            return ball.top_left
        elsif @orientation == QUAD_SW
            return ball.top_right
        elsif @orientation == QUAD_NE
            return ball.bottom_left
        elsif @orientation == QUAD_NW
            return ball.bottom_right
        end
        error("ERROR: Can't determine comparison corner point because of wall orientation #{@orientation}")
    end

    def inner_contains_ball(ball)
        comparison_corner = comparison_corner_point(ball)
        debug("Inner compare with diagonal. Comparison point: #{comparison_corner}")

        if contains_point(comparison_corner_point(ball))
            debug("Comparison corner contains point.")
            return true 
        end

        # Based on the radians, check points on the border
        if ball.direction < DEG_90
            #puts "Triangle: The ball is generally travelling NE"
            # check points top left and side right
            start_x = ball.center_x 
            while start_x < ball.right_edge
                #puts "Checking x #{start_x}, #{ball.y}"
                if contains_point(Point.new(start_x, ball.y))
                    return true 
                end
                start_x = start_x + 1
            end
            start_y = ball.y 
            while start_y < ball.center_y
                #puts "Checking x #{ball.right_x}, #{start_y}"
                if contains_point(Point.new(ball.right_edge, start_y))
                    return true 
                end
                start_y = start_y + 1
            end
        elsif ball.direction < DEG_180
            #puts "Triangle: The ball is generally travelling NW"
            start_x = ball.x 
            while start_x < ball.center_x
                #puts "Checking x #{start_x}, #{ball.y}"
                if contains_point(Point.new(start_x, ball.y))
                    return true 
                end
                start_x = start_x + 1
            end
            start_y = ball.y 
            while start_y < ball.center_y
                #puts "Checking x #{ball.x}, #{start_y}"
                if contains_point(Point.new(ball.x, start_y))
                    return true 
                end
                start_y = start_y + 1
            end
        elsif ball.direction < DEG_270
            #puts "Triangle: The ball is generally travelling SW"
            start_y = ball.center_y 
            while start_y < ball.bottom_edge
                #puts "Checking x #{ball.x}, #{start_y}"
                if contains_point(Point.new(ball.x, start_y))
                    return true 
                end
                start_y = start_y + 1
            end
            start_x = ball.x 
            while start_x < ball.center_x
                #puts "Checking x #{start_x}, #{ball.bottom_y}"
                if contains_point(Point.new(start_x, ball.bottom_edge))
                    return true 
                end
                start_x = start_x + 1
            end
        else 
            #puts "Triangle: The ball is generally travelling SE"
            start_x = ball.center_x 
            while start_x < ball.right_edge
                #puts "Checking x #{start_x}, #{ball.bottom_y}"
                if contains_point(Point.new(start_x, ball.bottom_edge))
                    return true 
                end
                start_x = start_x + 1
            end
            start_y = ball.center_y 
            while start_y < ball.bottom_edge
                #puts "Checking x #{ball.right_x}, #{start_y}"
                if contains_point(Point.new(ball.right_edge, start_y))
                    return true 
                end
                start_y = start_y + 1
            end
        end
    end
end

class Brick < GameObject
    def initialize(image)
        super(image)
        @can_move = false
    end

    def interaction_results
        [RDIA_REACT_BOUNCE, RDIA_REACT_CONSUME, RDIA_REACT_SCORE]
    end

    def score 
        10 
    end
end

class Dot < GameObject
    def initialize(image)
        super(image)
        @can_move = false
    end

    def interaction_results
        [RDIA_REACT_CONSUME, RDIA_REACT_SCORE]
    end

    def score 
        50 
    end
end

class OutOfBounds < GameObject
    def initialize(image)
        super(image)
        @can_move = false
    end

    def interaction_results
        [RDIA_REACT_LOSE, RDIA_REACT_STOP]
    end
end

class BackgroundArea < GameObject
    def initialize(image)
        super(image)
        @can_move = false
    end

    def interaction_results
        []
    end
end

class GoalArea < GameObject
    def initialize(image)
        super(image)
        @can_move = false
    end

    def interaction_results
        [RDIA_REACT_GOAL, RDIA_REACT_STOP]
    end
end

class BricksTheme < GuiTheme
    def initialize
        super(COLOR_WHITE,                # text color
              COLOR_HEADER_BRIGHT_BLUE,   # graphic elements
              COLOR_VERY_LIGHT_BLUE,      # border color
              COLOR_BLACK,                # background
              COLOR_LIGHT_GRAY,           # selected item
              true,                       # use icons
              Gosu::Font.new(22, {:name => media_path("armalite_rifle.ttf")}),  # regular font
              Gosu::Font.new(38, {:name => media_path("armalite_rifle.ttf")}))  # large font
    end

    def media_path(file)
        File.join(File.dirname(File.dirname(__FILE__)), 'media', file)
    end
end

class OverlayTheme < GuiTheme
    def initialize
        super(COLOR_WHITE,                # text color
              COLOR_HEADER_BRIGHT_BLUE,   # graphic elements
              COLOR_VERY_LIGHT_BLUE,      # border color
              COLOR_BLACK,                # background
              COLOR_LIGHT_GRAY,           # selected item
              true,                       # use icons
              Gosu::Font.new(22),  # regular font
              Gosu::Font.new(38))  # large font
    end

    def media_path(file)
        File.join(File.dirname(File.dirname(__FILE__)), 'media', file)
    end
end

class GameMessageOverlay < InfoBox
    def initialize(title, content_id)
        content_file_name = File.join(File.dirname(File.dirname(__FILE__)), 'data', "messages_#{content_id}.txt")
        if not File.exist?(content_file_name)
            raise "The content file #{content_file_name} does not exist"
        end
        content = File.readlines(content_file_name).join("")
        super(100, 60, 600, 400, title, content, { ARG_THEME => OverlayTheme.new})
    end

    def handle_key_press id, mouse_x, mouse_y
        if id == Gosu::KbEscape or id == Gosu::KbEnter or id == Gosu::KbSpace
            return WidgetResult.new(true)
        end
    end
end 


WadsConfig.instance.set_current_theme(BricksTheme.new)


BricksGame.new.show
