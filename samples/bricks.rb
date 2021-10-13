require 'gosu'
require 'wads'
require_relative '../lib/rdia-games'

include Wads
include RdiaGames


class BricksGame < RdiaGame
    def initialize
        super(600, 400, "Ruby Bricks", BricksDisplay.new)
    end 
end

class BricksDisplay < Widget
    def initialize
        super(0, 0, 600, 400)
        set_layout(LAYOUT_HEADER_CONTENT, {ARG_DESIRED_HEIGHT => 60})
        set_theme(WadsDarkRedBrownTheme.new)
        disable_border
        add_panel(SECTION_NORTH).get_layout.add_text("Bricks Game",
                                                     { ARG_TEXT_ALIGN => TEXT_ALIGN_CENTER,
                                                       ARG_USE_LARGE_FONT => true})
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
