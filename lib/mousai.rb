# frozen_string_literal: true

# The library's entry point: the application, plus the parts of the port that
# nothing in the window reaches yet.
#
# Everything the window builds is required through the application. The saved
# recordings, the waveform and the progress icon are reached only by upstream's
# recognizer and recognizer view, which need an audio recorder and so
# GStreamer's Ruby binding — not in the port's dependencies — so they are
# required here instead, as part of the library's surface.
require_relative "mousai/application"
require_relative "progress_icon"
require_relative "recordings"
require_relative "waveform"
