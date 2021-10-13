require 'gosu'
require 'wads'
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
    end 
end

class BricksDisplay < Widget
    def initialize
        super(0, 0, GAME_WIDTH, GAME_HEIGHT)
        set_layout(LAYOUT_HEADER_CONTENT, {ARG_DESIRED_HEIGHT => 60})
        #set_theme(WadsDarkRedBrownTheme.new)
        disable_border
        add_panel(SECTION_NORTH).get_layout.add_text("Bricks Game",
                                                     { ARG_TEXT_ALIGN => TEXT_ALIGN_CENTER,
                                                       ARG_USE_LARGE_FONT => true})

        @tileset = Gosu::Image.load_tiles("media/basictiles.png", 16, 16, tileable: true)
        @image_widget = ImageWidget.new(10, 110, @tileset[0])
        #add_child(@image_widget)
        @grid = GridDisplay.new(0, 100, 16, 50, 30)
        @grid.disable_border
        add_child(@grid)

    end 

    def handle_update update_count, mouse_x, mouse_y
        # nothing to do yet
    end

    def handle_button_click
        # nothing to do yet
    end

    def handle_key_press id, mouse_x, mouse_y
        # nothing to do yet
    end
end

BricksGame.new.show
