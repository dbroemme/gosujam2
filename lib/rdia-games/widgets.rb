require 'wads'

include Wads 

module RdiaGames

    class GridDisplay < Widget 
        attr_accessor :grid_size 
        attr_accessor :map

        # TODO Add visible area for scrolling purposes
        def initialize(x, y, grid_size, grid_width, grid_height, args = {})
            @grid_size = grid_size
            width = @grid_size * grid_width 
            height = @grid_size * grid_height
            super(x, y, width, height)
            if args[ARG_THEME]
                @gui_theme = args[ARG_THEME]
            end
            @tiles = Array.new(grid_width) do |x|
                Array.new(grid_height) do |y|
                    nil 
                end 
            end 
            puts "Populated tiles: #{@tiles}"
        end

        def grid_to_relative_pixel(val)
            val * @grid_size
        end

        def set_tile(tile_x, tile_y, widget)
            # TODO check that it is not out of bounds
            @map[tile_x][tile_y] = widget 
        end

        def render 
            # TODO iterate through map and draw the tiles
        end
    end
end
