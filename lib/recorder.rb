# frozen_string_literal: true

require "gio2"
require "gstreamer"
require_relative "device"
require_relative "settings"

module Mousai
  # Records audio to an in-memory Ogg/Opus buffer.
  #
  # Ported from upstream's src/recognizer/recorder.rs: the
  # pulsesrc → audioconvert → level → opusenc → oggmux → giostreamsink
  # pipeline, built against either the default microphone or the default
  # desktop audio sink's monitor depending on `audio_source_type`, and the bus
  # watch that turns the `level` element's peak meter into the peak callback
  # and stops the main loop at end of stream.
  class Recorder
    class Error < StandardError; end

    LEVEL_INTERVAL_NS = 80_000_000
    OPUS_BITRATE = 16_000
    SAMPLE_RATE = 16_000

    def initialize
      @pipeline = nil
    end

    # Builds and starts the pipeline. `peak_callback` is called with the
    # normalized (0..1-ish) peak on every `level` interval — upstream's
    # `start`.
    def start(audio_source_type, &peak_callback)
      unless @pipeline.nil?
        raise(Error, "there is already a recording in progress")
      end

      stream = Gio::MemoryOutputStream.new
      pipeline = create_pipeline(stream, audio_source_type)

      watch_id = pipeline.bus.add_watch(GLib::PRIORITY_DEFAULT) do |_bus, message|
        handle_bus_message(pipeline, message, peak_callback)
      end

      @pipeline = [pipeline, watch_id, stream]

      pipeline.set_state(Gst::State::PLAYING)

      nil
    end

    # Stops the pipeline and returns the recorded bytes — upstream's `stop`.
    def stop
      (@pipeline || raise(Error, "Recording has not been started")).then do |(pipeline, watch_id, stream)|
        @pipeline = nil

        pipeline.set_state(Gst::State::NULL)
        GLib::Source.remove(watch_id)
        stream.close

        stream.steal_as_bytes.to_s
      end
    end

    private

      def handle_bus_message(pipeline, message, peak_callback)
        case message.type
        when Gst::MessageType::ELEMENT
          handle_element_message(message, peak_callback)
          GLib::Source::CONTINUE
        when Gst::MessageType::EOS
          GLib::Source::REMOVE
        when Gst::MessageType::ERROR
          warn("Received error at bus while recording (state #{pipeline.current_state}): #{message.error&.message}")
          GLib::Source::REMOVE
        else
          GLib::Source::CONTINUE
        end
      end

      # The `level` element's peak meter, converted from decibels the way
      # upstream's `handle_bus_message` does: `10f64.powf(peak / 20.0)`.
      def handle_element_message(message, peak_callback)
        structure = message.structure

        if structure && structure.has_name?("level") && structure.has_field?("peak")
          structure.get_value("peak").value.first.then do |peak_db|
            if peak_db && peak_callback
              peak_callback.call(10**(peak_db / 20.0))
            end
          end
        end
      end

      def make_pulsesrc(audio_source_type)
        Gst::ElementFactory.find("pulsesrc").create.tap do |pulsesrc|
          case audio_source_type
          when Settings::DESKTOP_AUDIO
            device = Device.find_default(Device::SINK)
            pulsesink = device.create_element(nil)
            device_name = pulsesink.device.to_s

            if device_name.empty?
              raise(Error, "Empty device name")
            end

            pulsesrc.device = "#{device_name}.monitor"
          else
            device = Device.find_default(Device::SOURCE)
            device.reconfigure_element(pulsesrc)

            if pulsesrc.device.to_s.empty?
              raise(Error, "Empty device name")
            end
          end
        end
      end

      def create_pipeline(stream, audio_source_type)
        pulsesrc = make_pulsesrc(audio_source_type)
        audioconvert = Gst::ElementFactory.find("audioconvert").create
        level = Gst::ElementFactory.find("level").create.tap do |l|
          l.interval = LEVEL_INTERVAL_NS
          l.peak_ttl = LEVEL_INTERVAL_NS
        end
        opusenc = Gst::ElementFactory.find("opusenc").create.tap { |enc| enc.bitrate = OPUS_BITRATE }
        oggmux = Gst::ElementFactory.find("oggmux").create
        giostreamsink = Gst::ElementFactory.find("giostreamsink").create.tap { |sink| sink.stream = stream }

        elements = [pulsesrc, audioconvert, level, opusenc, oggmux, giostreamsink]

        Gst::Pipeline.new.tap do |pipeline|
          elements.each { |element| pipeline.add(element) }

          pulsesrc.link_filtered(audioconvert, Gst::Caps.from_string("audio/x-raw,channels=1,rate=#{SAMPLE_RATE}"))
          audioconvert.link(level)
          level.link(opusenc)
          opusenc.link_filtered(oggmux, Gst::Caps.from_string("audio/x-opus"))
          oggmux.link_filtered(giostreamsink, Gst::Caps.from_string("audio/ogg"))

          elements.each(&:sync_state_with_parent)
        end
      end
  end
end
