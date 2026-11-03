# frozen_string_literal: true

# Drives the playback and recognition side: the player and the song bar, the
# test providers, the saved recordings, the two drawn widgets and the three
# dialogs.

require "tmpdir"

ENV["XDG_CONFIG_HOME"] = Dir.mktmpdir("mousai-config")
ENV["XDG_DATA_HOME"] = Dir.mktmpdir("mousai-data")

require_relative "gtk_driver"
require_relative "../lib/mousai"

app = Mousai::Application.new

# A one-second 440 Hz tone, written by hand so the run needs no encoder and no
# network. GTK's GStreamer media backend aborts on a URI whose host does not
# resolve, so a drive run must never point the player at one.
def tone_uri
  File.join(Dir.mktmpdir("mousai-tone"), "tone.wav").then do |path|
    44_100.then do |rate|
      (0...rate)
        .map { |index| (Math.sin(2 * Math::PI * 440 * index / rate) * 12_000).to_i }
        .pack("s<*")
        .then do |data|
          File.binwrite(
            path,
            [
              "RIFF", 36 + data.bytesize, "WAVE",
              "fmt ", 16, 1, 1, rate, rate * 2, 2, 16,
              "data", data.bytesize,
            ].pack("a4Va4a4VvvVVvva4V") + data,
          )
        end
    end

    "file://#{path}"
  end
end

PLAYBACK_LINK = tone_uri

def sample_song(title, artist, **rest)
  Mousai::Song.build(
    id:     Mousai::Uid.from_prefixed("test", title),
    title:  title,
    artist: artist,
    album:  "An Album",
    **rest,
  ).tap { |song| song.last_heard = Mousai::DateTime.now_utc }
end

GtkDriver.drive(app, shots: "tmp/shots") do |d, application|
  d.window { application.window.root }
  window = -> { application.window }
  player = -> { application.player }

  d.step("the window opens with the song bar hidden") do
    d.check("no song on the player") { player.call.song.nil? }
    d.check("the player is stopped") { player.call.state == Mousai::Player::STOPPED }
    d.check("the song bar is not revealed") { !window.call.song_bar_revealer.reveal_child? }
    d.check("toggle-playback is disabled") { !window.call.toggle_playback_action.enabled? }
  end

  d.step("a song with a playback link is put on the player") do
    application.song_list.insert(sample_song("Africa", "Toto", playback_link: PLAYBACK_LINK))
    player.call.song = application.song_list.to_a.first
  end

  d.step("the song bar comes up for it") do
    d.check("the song bar is revealed") { window.call.song_bar_revealer.reveal_child? }
    d.check("toggle-playback is enabled") { window.call.toggle_playback_action.enabled? }
    d.check("the title is shown") { window.call.song_bar.title_label.label == "Africa" }
    d.check("the artist is shown") { window.call.song_bar.artist_label.label == "Toto" }
    d.check("the seek scale is sensitive") { window.call.song_bar.playback_position_scale.sensitive? }
    d.check("the position label reads MM∶SS / MM∶SS") do
      window.call.song_bar.playback_position_duration_label.label.match?(/\A\d+∶\d{2} \/ \d+∶\d{2}\z/)
    end
    d.check("the song is the active one") do
      player.call.active_song?(application.song_list.to_a.first.id)
    end
    d.shot("20-song-bar")
  end

  d.step("win.toggle-playback starts it") do
    window.call.toggle_playback_action.activate(nil)
  end

  d.step("the player is playing it") do
    d.check("the player is playing") { player.call.state == Mousai::Player::PLAYING }
    d.check("the duration was read off the stream") { player.call.duration.positive? }
    d.check("the seek scale's range follows the duration") do
      window.call.song_bar.playback_position_scale.adjustment.upper == player.call.duration
    end
    d.check("the playback button offers a pause") do
      window.call.song_bar.playback_button.mode == Mousai::PlaybackButton::PAUSE
    end
  end

  d.step("win.toggle-playback pauses it again") do
    window.call.toggle_playback_action.activate(nil)
  end

  d.step("the player is paused") do
    d.check("the player is paused") { player.call.state == Mousai::Player::PAUSED }
    d.check("the playback button offers a play") do
      window.call.song_bar.playback_button.mode == Mousai::PlaybackButton::PLAY
    end
  end

  d.step("the narrow breakpoint switches the bar's layout") do
    window.call.song_bar.adaptive_mode = :narrow
  end

  d.step("the bar is in its narrow layout") do
    d.check("layout name is narrow") do
      window.call.song_bar.multi_layout_view.layout_name == Mousai::SongBar::NARROW_LAYOUT
    end
    d.shot("21-song-bar-narrow")
    window.call.song_bar.adaptive_mode = :normal
  end

  d.step("the song bar's clear action takes the song off the player") do
    window.call.song_bar.clear_action.activate(nil)
  end

  d.step("the bar goes away again") do
    d.check("no song on the player") { player.call.song.nil? }
    d.check("the song bar is not revealed") { !window.call.song_bar_revealer.reveal_child? }
    d.check("toggle-playback is disabled again") { !window.call.toggle_playback_action.enabled? }
  end

  d.step("the mock provider recognizes a song") do
    Mousai::ProviderSettings.lock do |settings|
      settings.test_mode = Mousai::TestProviderMode::VALID_ONLY
      settings.test_recognize_duration = 0.0
    end

    @recognized = Mousai::AudDMock.new.recognize("not really audio")
  end

  d.step("the recognized song is a song") do
    d.check("a song came back") { @recognized.is_a?(Mousai::Song) }
    d.check("it has a title") { !@recognized.title.empty? }
    d.check("it has an artist") { !@recognized.artist.empty? }
    d.check("it has an AudD link") do
      @recognized.external_links.key?(Mousai::ExternalLinks::AUD_D_URL)
    end
    d.check("its id is prefixed with the provider") { @recognized.id.to_s.start_with?("AudD-") }
    d.check("the provider says it is a test provider") { Mousai::AudDMock.new.test? }
  end

  d.step("the mock provider's error responses raise") do
    Mousai::ProviderSettings.lock do |settings|
      settings.test_mode = Mousai::TestProviderMode::ERROR_ONLY
    end

    begin
      Mousai::AudDMock.new.recognize("not really audio")
      @mock_error = nil
    rescue Mousai::RecognizeError => e
      @mock_error = e
    end
  end

  d.step("an error came back instead of a song") do
    d.check("a recognize error was raised") { @mock_error.is_a?(Mousai::RecognizeError) }
    d.check("it has a title") { !@mock_error.title.empty? }
  end

  d.step("the error tester walks every error kind") do
    @tester_kinds = Array.new(Mousai::RecognizeError::KINDS.length) do
      begin
        Mousai::ErrorTester.new.recognize("not really audio")
        nil
      rescue Mousai::RecognizeError => e
        e.kind
      end
    end
  end

  d.step("it produced each kind once") do
    d.check("one error per kind") do
      @tester_kinds.compact.sort == Mousai::RecognizeError::KINDS.sort
    end
    d.check("the permanent kinds are the documented ones") do
      @tester_kinds.compact.select { |kind| Mousai::RecognizeError.new(kind).permanent? }.sort ==
        Mousai::RecognizeError::PERMANENT_KINDS.sort
    end
  end

  d.step("a recording is saved, read back and taken") do
    Mousai::Recordings.new(database: application.database).then do |recordings|
      recording = Mousai::Recording.new("some bytes", Mousai::DateTime.now_utc)
      recordings.insert(recording)
      recording.recognize_result = Mousai::RecognizeError.new(Mousai::RecognizeError::CONNECTION, "offline")

      @reloaded = Mousai::Recordings.new(database: application.database).load
      @taken = recordings.take_filtered { true }
    end
  end

  d.step("the recording round-tripped through the database") do
    d.check("one recording was reloaded") { @reloaded.n_items == 1 }
    d.check("its bytes survived") { @reloaded.item(0).bytes == "some bytes" }
    d.check("its error survived") do
      @reloaded.item(0).recognize_error&.kind == Mousai::RecognizeError::CONNECTION
    end
    d.check("one recording was taken") { @taken.length == 1 }
  end

  d.step("a window holding the waveform and the progress icon opens") do
    @waveform = Mousai::Waveform.new.tap(&:build)
    @progress_icon = Mousai::ProgressIcon.new.tap(&:build)
    @progress_icon.root.width_request = 64
    @progress_icon.root.height_request = 64

    Gtk::Window.new.tap do |drawn_window|
      drawn_window.set_default_size(300, 320)
      drawn_window.child = Gtk::Box.new(:vertical, 12).tap do |box|
        box.append(@waveform.root)
        box.append(@progress_icon.root)
      end
      drawn_window.present
      @drawn_window = drawn_window
    end
  end

  d.step("peaks and a progress are fed to them") do
    d.check("the waveform is allocated") { @waveform.root.width.positive? }
    d.check("it has room for several peaks") { @waveform.max_n_peaks > 1 }

    20.times { |index| @waveform.push_peak(((index % 7) + 1) / 7.0) }
    @progress_icon.progress = 0.4
  end

  d.step("they rendered") do
    d.check("the waveform kept the peaks it can draw") { @waveform.max_n_peaks > 1 }
    d.check("the progress icon took the progress") { @progress_icon.progress == 0.4 }
    d.check("the window is mapped") { @drawn_window.mapped? }
    d.shot("22-waveform", @drawn_window)
    @drawn_window.close
  end

  d.step("the recognize error dialog opens for a permanent failure") do
    window.call.present_recognize_error(
      Mousai::RecognizeError.new(Mousai::RecognizeError::NO_MATCHES),
    )
  end

  d.step("its open animation settles") { nil }

  d.step("it is showing") do
    d.shot("23-recognize-error")
    application.window.root.visible_dialog&.close
  end

  d.step("the recording saved dialog opens for a connection failure") do
    window.call.present_recording_saved_message(
      Mousai::RecognizeError.new(Mousai::RecognizeError::CONNECTION, "offline"),
    )
  end

  d.step("its open animation settles too") { nil }

  d.step("it is showing too") do
    d.shot("24-recording-saved")
    application.window.root.visible_dialog&.close
  end

  d.step("the database error dialog opens") do
    Mousai::DatabaseErrorDialog.present(application.window.root) { nil }
  end

  d.step("its open animation settles as well") { nil }

  d.step("it is showing as well") do
    d.shot("25-database-error")
    application.window.root.visible_dialog&.close
  end
end
