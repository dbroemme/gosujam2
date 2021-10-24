require 'wads'
require_relative 'widgets'

include Wads

module RdiaGames

    RDIA_MODE_START = "start"
    RDIA_MODE_RESTART = "restart"
    RDIA_MODE_PREPARE = "prepare"
    RDIA_MODE_PLAY = "play"
    RDIA_MODE_END = "end"

    ARG_SCALE = "scale"
    ARG_DELAY = "delay"
    ARG_PROGRESS_AMOUNT = "progress_amount"

    #
    # The WadsApp class provides a simple starting point to quickly build a native
    # Ruby application using Gosu as an underlying library. It provides all the necessary
    # hooks to get started. All you need to do is supply the parent Wads widget using
    # the set_display(widget) method. See one of the Wads samples for example usage.
    #
    class RdiaGame < WadsApp
        def initialize(width, height, caption, widget)
            super
        end 
    end 
end
