#require 'wads'
require_relative '../../../ruby-wads/lib/wads'
require 'securerandom'
require 'set'

include Wads 

module RdiaGames

    # Possible interactions when one object hits another
    RDIA_REACT_BOUNCE = "bounce"
    RDIA_REACT_BOUNCE_DIAGONAL = "diagonal"
    RDIA_REACT_CONSUME = "consume"
    RDIA_REACT_GOAL = "goal"
    RDIA_REACT_STOP = "stop"

    QUAD_NW = 1
    QUAD_N = 2
    QUAD_NE = 3
    QUAD_E = 4
    QUAD_SE = 5
    QUAD_S = 6
    QUAD_SW = 7
    QUAD_W = 8

    TIE_DIM = 0
    X_DIM = 1
    Y_DIM = 2

    class GameObject < ImageWidget 
        attr_accessor :direction
        attr_accessor :speed
        attr_accessor :acceleration
        attr_accessor :can_move
        attr_accessor :object_id

        def initialize(image, args = {})
            super(0, 0, image)
            object_id = SecureRandom.uuid
            init_direction_and_speed
            @can_move = true  # Set to false if this is a wall or other immovable object
        end

        def init_direction_and_speed 
            @direction = DEG_0
            @acceleration = 0
            @speed = 0
        end

        def speed_up 
            if @acceleration < 8
                @acceleration = @acceleration + 0.2
            end
            info("speed = #{@speed} + #{@acceleration}")
            @speed = @speed + @acceleration
            if @speed > 12
                @speed = 12
            end
        end 
    
        def slow_down 
            if @acceleration > 0
                @acceleration = @acceleration - 0.2
            end
            @speed = @speed - @acceleration
            if @speed < 0
                @speed = 0
            end
        end 

        def start_move_in_direction(direction)
            if direction.is_a? Numeric
                @direction = direction 
            else 
                raise "move_in_direction takes a numeric value in radians"
            end 
        end 

        def start_move_right
            start_move_in_direction(DEG_0)
            @acceleration = 0
            @speed = 0
        end

        def start_move_left
            start_move_in_direction(DEG_180)
            @acceleration = 0
            @speed = 0
        end

        def proposed_move
            [@x + Math.cos(@direction), @y - Math.sin(@direction)]
        end

        def stop_move
            @acceleration = 0
            @speed = 0
        end

        def distance_between_center_mass(other_object)
            (other_object.center_x - center_x).abs + (other_object.center_y - center_y).abs
        end 

        def relative_quad(other_object)
            # TODO we don't consider N, S, E, W right now
            if @x < other_object.x
                # West side
                if @y < other_object.y 
                    return QUAD_NW 
                else 
                    return QUAD_SW 
                end
            else 
                # East side
                if @y < other_object.y 
                    return QUAD_NE
                else 
                    return QUAD_SE 
                end
            end
        end
    
        def x_or_y_dimension_greater_distance(x, y)
            dx = (x - center_x).abs
            dy = (y - center_y).abs
            if dx == dy 
                return TIE_DIM 
            elsif dx < dy 
                return Y_DIM 
            end  
            return X_DIM
        end

        def overlaps_with_proposed(proposed_x, proposed_y, other_widget)
            # Darren
            delta_x = proposed_x - @x
            delta_y = proposed_y - @y

            if other_widget.contains_click(@x + delta_x, @y + delta_y)
                return true
            end
            if other_widget.contains_click(right_edge + delta_x, @y + delta_y)
                return true
            end
            if other_widget.contains_click(right_edge + delta_x, bottom_edge - 1 + delta_y)
                return true
            end
            if other_widget.contains_click(@x + delta_x, bottom_edge - 1 + delta_y)
                return true
            end
            if other_widget.contains_click(center_x + delta_x, center_y + delta_y)
                return true
            end
            return false
        end

        #
        # Radians bounce helpers
        #
        def will_hit_axis(axis, radians) 
            begin_range = axis 
            end_range = axis - DEG_180
            if end_range < DEG_0
                end_range = DEG_360 - end_range.abs
            end 
            #puts "Axis #{axis}  Begin/end  #{begin_range}/#{end_range}   #{radians}"
            if begin_range < end_range 
                return (radians < begin_range or radians > end_range)
            end
            radians < begin_range and radians > end_range
        end 
        
        def bounce_x
            @direction = calculate_bounce(DEG_270, @direction)
        end
    
        def bounce_y
            @direction = calculate_bounce(DEG_360, @direction)
        end

        def calculate_bounce(axis, radians)
            truncate_bounce(reflect_bounce(axis, radians))
        end
        
        def truncate_bounce(radians)
            if radians < DEG_0
                return DEG_360 - radians.abs 
            elsif radians > DEG_360 
                return radians - DEG_360 
            end
            radians 
        end
        
        def reflect_bounce(axis, radians)
            amount_reflection = axis - radians
            radians = axis + amount_reflection
        end
    end 

    class Ball < GameObject
        def initialize(x, y)
            super(COLOR_WHITE)
            init_direction_and_speed 
            set_absolute_position(x, y)
            set_dimensions(12, 12)
        end
    end 

    class Player < GameObject 
        attr_accessor :tile_width 
        attr_accessor :tile_height 

        def initialize(image, tile_width, tiles_height, args = {})
            super(image)
            @tile_width = tile_width 
            @tile_height = tile_height
            width = image.width * tile_width
            height = image.height * tiles_height
            set_dimensions(width, height)
            disable_border
        end

        def render 
            x = @x
            tile_width.times do 
                @img.draw x, @y, relative_z_order(Z_ORDER_GRAPHIC_ELEMENTS)
                x = x + @img.width 
            end
        end

        def move_right(grid)
            speed_up
            player_move(grid)
        end

        def move_left(grid)
            speed_up
            player_move(grid)
        end

        def player_move(grid)
            @speed.round.times do
                proposed_next_x, proposed_next_y = proposed_move
                widgets_at_proposed_spot = grid.proposed_widget_at(self, proposed_next_x, proposed_next_y)
                if widgets_at_proposed_spot.empty?
                    set_absolute_position(proposed_next_x, proposed_next_y)
                else 
                    debug("Can't move any further because widget(s) are there #{widgets_at_proposed_spot}")
                end
            end
        end
    end 


    class GridDisplay < Widget 
        attr_accessor :tile_size 
        attr_accessor :grid_width 
        attr_accessor :grid_height 
        attr_accessor :tiles

        # TODO Add visible area for scrolling purposes
        def initialize(x, y, tile_size, grid_width, grid_height, args = {})
            @tile_size = tile_size
            @grid_width = grid_width 
            @grid_height = grid_height
            width = @tile_size * @grid_width 
            height = @tile_size * @grid_height
            super(x, y, width, height)
            if args[ARG_THEME]
                @gui_theme = args[ARG_THEME]
            end
            clear_tiles
            #puts "Populated tiles: #{@map}"
        end

        def clear_tiles
            @tiles = Array.new(@grid_width) do |x|
                Array.new(@grid_height) do |y|
                    nil
                end 
            end 
        end

        def grid_to_relative_pixel(val)
            val * @tile_size
        end

        def set_tile(tile_x, tile_y, widget)
            if tile_x < 0 or tile_y < 0
                raise "Cannot set tile at negative numbers"
            end
            if tile_x >= @grid_width
                raise "Cannot set tile at x #{tile_x}, max width is #{@grid_width - 1}"
            elsif tile_y >= @grid_height
                raise "Cannot set tile at y #{tile_y}, max height is #{@grid_height - 1}"
            end
            widget.x = relative_x(grid_to_relative_pixel(tile_x))
            widget.y = relative_y(grid_to_relative_pixel(tile_y))
            @tiles[tile_x][tile_y] = widget 
        end

        def remove_tile_at_absolute(x, y)
            tile_x = (x - @x) / @tile_size
            tile_y = (y - @y) / @tile_size
            remove_tile(tile_x, tile_y)
        end 

        def remove_tile(tile_x, tile_y)
            @tiles[tile_x][tile_y] = nil 
        end

        def render
            (0..grid_width-1).each do |x|
                (0..grid_height-1).each do |y|
                    img = @tiles[x][y]
                    if img.nil?
                        # nothing to do 
                    else 
                        img.draw
                    end 
                end 
            end
        end

        # Returns nil if there is no widget at the given pixel position
        # or if it this pixel is occupied, return the widget at that position
        def widget_at_absolute(x, y)
            widget_at_relative(x - @x, y - @y)
        end

        # Returns nil if there is no widget at the given pixel position
        # or if it this pixel is occupied, return the widget at that position
        def widget_at_relative(x, y)
            @tiles[x / @tile_size][y / @tile_size]
        end

        def proposed_widget_at(ball, proposed_next_x, proposed_next_y)
            widgets = []
            delta_x = proposed_next_x - ball.x
            delta_y = proposed_next_y - ball.y

            other_widget = widget_at_absolute(ball.x + delta_x, ball.y + delta_y)  # Top left corner check
            widgets << other_widget unless other_widget.nil?
            other_widget = widget_at_absolute(ball.right_edge + delta_x, ball.y + delta_y) # Top right corner check
            widgets << other_widget unless other_widget.nil?
            other_widget = widget_at_absolute(ball.right_edge + delta_x, ball.bottom_edge + delta_y) # Lower right corner check
            widgets << other_widget unless other_widget.nil?
            other_widget = widget_at_absolute(ball.x + delta_x, ball.bottom_edge + delta_y) # Lower left corner check
            widgets << other_widget unless other_widget.nil?
            other_widget = widget_at_absolute(ball.center_x + delta_x, ball.center_y + delta_y) # Center check
            widgets << other_widget unless other_widget.nil?
            # TODO Make dedup more efficient
            #info("Before Deduped there are #{widgets.size} widgets")
            ids = Set.new
            deduped_widgets = []
            widgets.each do |w|
                if ids.include? w.object_id 
                    # skip
                else 
                    ids.add(w.object_id)
                    deduped_widgets << w 
                end 
            end
            #info("Deduped there are #{deduped_widgets.size} widgets")
            deduped_widgets
        end

    end
end
