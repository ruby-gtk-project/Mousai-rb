# frozen_string_literal: true

require "adwaita"
require_relative "album_cover"
require_relative "external_link_tile"
require_relative "i18n"
require_relative "information_row"
require_relative "playback_button"
require_relative "player"
require_relative "song"

module Mousai
  # The page showing everything known about one song.
  #
  # Ported from upstream's src/window/song_page.rs and
  # data/resources/ui/song_page.ui: the album art and title block, the "Listen"
  # group of provider tiles, and the information rows — last heard, album,
  # release date and a row that opens the lyrics page.
  #
  # The playback button under the title is there for a song that has a playback
  # link; it shows the player's state while that song is the active one, and
  # clicking it puts the song on the player or pauses it again.
  class SongPage
    NORMAL_ALBUM_COVER_PIXEL_SIZE = 180
    NARROW_ALBUM_COVER_PIXEL_SIZE = 120
    PLAYBACK_BUTTON_SIZE = 40

    attr_reader :song, :adaptive_mode

    # `song_list` is what the remove button's sensitivity follows: a song that
    # is no longer in the history cannot be removed again.
    def initialize(song_list:, player:, album_art_store:, on_toast: nil)
      @song_list = song_list
      @player = player
      @album_art_store = album_art_store
      @on_toast = on_toast
      @adaptive_mode = :normal
      @remove_request_listeners = []
      @show_lyrics_request_listeners = []
      @external_link_tiles = []
      @song_list.on_items_changed { update_remove_button_sensitivity }
    end

    def build
      root.tap do |page|
        page.insert_action_group("song-page", action_group)

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = scroller

          header_bar.tap do |bar|
            bar.title_widget = window_title
            bar.pack_end(remove_button)
            bar.pack_end(copy_button)

            remove_button.tap do |button|
              button.signal_connect("clicked") { request_remove }
            end
          end

          scroller.tap do |window|
            window.child = clamp

            clamp.tap do |c|
              c.child = content_box
            end
          end
        end

        content_box.tap do |box|
          box.append(header_box)
          box.append(listen_group)
          box.append(information_group)

          header_box.tap do |b|
            b.append(album_cover.build)
            b.append(title_box)

            title_box.tap do |tb|
              tb.append(title_label)
              tb.append(artist_label)
              tb.append(playback_button.build)

              playback_button.tap do |button|
                button.root.signal_connect("clicked") { toggle_playback }
              end
            end
          end

          listen_group.tap do |group|
            group.add(external_links_box)

            external_links_box.tap do |flow_box|
              flow_box.signal_connect("child-activated") do |_, child|
                activate_external_link(child)
              end
            end
          end

          information_group.tap do |group|
            group.add(last_heard_row.build)
            group.add(album_row.build)
            group.add(release_date_row.build)
            group.add(lyrics_row)

            lyrics_row.tap do |row|
              row.add_suffix(lyrics_row_arrow)
              row.signal_connect("activated") { request_show_lyrics }
            end
          end
        end

        @player.on_state_changed { update_playback_ui }
      end.tap do
        update_information
        update_page_title
        update_remove_button_sensitivity
        update_album_cover_size
        update_playback_ui
      end
    end

    def song=(new_song)
      new_song.then do |song|
        unless song == @song
          @song = song
          update_song_ui
        end
      end
    end

    def adaptive_mode=(mode)
      mode.then do |adaptive_mode|
        unless adaptive_mode == @adaptive_mode
          @adaptive_mode = adaptive_mode
          update_album_cover_size
        end
      end
    end

    def on_song_remove_request(&block)
      @remove_request_listeners << block
      block
    end

    def on_show_lyrics_request(&block)
      @show_lyrics_request_listeners << block
      block
    end

    def root = @root ||= Adwaita::NavigationPage.new(toolbar_view, "")
    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def window_title = @window_title ||= Adwaita::WindowTitle.new("", "")

    def remove_button
      @remove_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = I18n.gettext("Remove From History")
        button.icon_name = "user-trash-symbolic"
      end
    end

    def copy_button
      @copy_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = I18n.gettext("Copy")
        button.icon_name = "edit-copy-symbolic"
        button.action_name = "song-page.copy-song"
      end
    end

    # The page's own action group — upstream's `song-page.copy-song`,
    # installed via `install_action` in `src/window/song_page.rs`.
    def action_group
      @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(copy_song_action)
      end
    end

    def copy_song_action
      @copy_song_action ||= Gio::SimpleAction.new("copy-song").tap do |action|
        action.signal_connect("activate") { copy_song }
      end
    end

    def scroller = @scroller ||= Gtk::ScrolledWindow.new
    def clamp = @clamp ||= Adwaita::Clamp.new

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 24).tap do |box|
        box.margin_start = 24
        box.margin_end = 24
        box.margin_top = 24
        box.margin_bottom = 24
      end
    end

    def header_box = @header_box ||= Gtk::Box.new(:horizontal, 24)

    def album_cover
      @album_cover ||= AlbumCover.new.tap do |cover|
        cover.root.valign = :center
      end
    end

    def title_box = @title_box ||= Gtk::Box.new(:vertical, 6)

    def playback_button
      @playback_button ||= PlaybackButton.new.tap do |button|
        button.root.halign = :start
        button.root.width_request = PLAYBACK_BUTTON_SIZE
        button.root.height_request = PLAYBACK_BUTTON_SIZE
        button.root.add_css_class("circular")
      end
    end

    def title_label
      @title_label ||= Gtk::Label.new.tap do |label|
        label.hexpand = true
        label.xalign = 0
        label.ellipsize = :end
        label.wrap = true
        label.wrap_mode = :word
        label.lines = 2
        label.add_css_class("title-1")
      end
    end

    def artist_label
      @artist_label ||= Gtk::Label.new.tap do |label|
        label.hexpand = true
        label.xalign = 0
        label.ellipsize = :end
        label.wrap = true
        label.wrap_mode = :word
        label.lines = 2
        label.add_css_class("title-4")
        label.add_css_class("dim-label")
      end
    end

    def listen_group
      @listen_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = I18n.gettext("Listen")
      end
    end

    def external_links_box
      @external_links_box ||= Gtk::FlowBox.new.tap do |flow_box|
        flow_box.selection_mode = :none
        flow_box.activate_on_single_click = true
        flow_box.column_spacing = 6
        flow_box.row_spacing = 6
      end
    end

    def information_group
      @information_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = I18n.gettext("Information")
      end
    end

    def last_heard_row = @last_heard_row ||= InformationRow.new(title: I18n.gettext("Last Heard"))
    def album_row = @album_row ||= InformationRow.new(title: I18n.gettext("Album"))

    def release_date_row
      @release_date_row ||= InformationRow.new(title: I18n.gettext("Release Date"))
    end

    def lyrics_row
      @lyrics_row ||= Adwaita::ActionRow.new.tap do |row|
        row.title = I18n.gettext("Lyrics")
        row.activatable = true
      end
    end

    def lyrics_row_arrow
      @lyrics_row_arrow ||= Gtk::Image.new.tap do |image|
        image.valign = :center
        image.icon_name = "go-next-symbolic"
        image.accessible_role = :presentation
      end
    end

    private

      def request_remove
        @remove_request_listeners.each { |listener| listener.call(self) }
      end

      def request_show_lyrics
        @show_lyrics_request_listeners.each { |listener| listener.call(self) }
      end

      # Upstream puts "Artist - Title" on the clipboard and says so in a toast.
      def copy_song
        @song.then do |song|
          if song
            root.display.clipboard.set(song.artist_title_text)
            @on_toast&.call(I18n.gettext("Copied to clipboard"))
          end
        end
      end

      def activate_external_link(child)
        @external_link_tiles.find { |tile| tile.root == child }.then do |tile|
          tile&.handle_activation(root.root)
        end
      end

      def update_song_ui
        title_label.label = @song&.title.to_s
        artist_label.label = @song&.artist.to_s
        show_album_art
        lyrics_row.visible = !@song&.lyrics.nil?
        update_information
        update_page_title
        update_remove_button_sensitivity
        update_playback_ui
      end

      # Upstream only cross-fades when the album art has still to be
      # downloaded, so a cover that can be shown at once does not fade in.
      def show_album_art
        @song&.album_art_link.then do |link|
          album_art_of(link).then do |album_art|
            album_cover.enables_crossfade = album_art.nil? || !album_art.loaded?
            album_cover.paintable = album_art&.cached_texture
            request_album_art(album_art, link)
          end
        end
      end

      def album_art_of(link)
        if link
          @album_art_store.get_or_init(link)
        end
      end

      # Upstream's album cover takes the song and downloads its art itself; the
      # port's cover takes a texture, so the download is asked for here and the
      # answer is dropped once the page has moved on to another song.
      def request_album_art(album_art, link)
        if album_art && !album_art.loaded?
          album_art.texture do |texture|
            if @song&.album_art_link == link
              album_cover.paintable = texture
            end
          end
        end
      end

      # Upstream's `toggle_playback`: the active song is paused, any other song
      # is put on the player and started.
      def toggle_playback
        @song.then do |song|
          if song
            if @player.state == Player::PLAYING && @player.active_song?(song.id)
              @player.pause
            else
              @player.song = song
              @player.play
            end
          end
        end
      end

      # Upstream's `update_playback_ui`: the button is only there for a song
      # that can be played, and it follows the player while that song is the
      # active one.
      def update_playback_ui
        playback_button.root.visible = !@song&.playback_link.to_s.empty?

        @song.then do |song|
          if song
            playback_button.mode = playback_button_mode(song)
          end
        end
      end

      def playback_button_mode(song)
        @player.active_song?(song.id).then do |is_active_song|
          if is_active_song && @player.state == Player::BUFFERING
            PlaybackButton::BUFFERING
          elsif is_active_song && @player.state == Player::PLAYING
            PlaybackButton::PAUSE
          else
            PlaybackButton::PLAY
          end
        end
      end

      def update_information
        rebuild_external_links
        last_heard_row.value = last_heard_text
        album_row.value = @song&.album.to_s
        release_date_row.value = @song&.release_date.to_s
      end

      def last_heard_text
        @song&.last_heard.then do |last_heard|
          if @song.nil?
            ""
          elsif last_heard
            last_heard.to_local.fuzzy_display
          else
            I18n.gettext("Unknown")
          end
        end
      end

      # The flow box holds one tile per link the port can handle, rebuilt
      # whenever the song changes — upstream binds a filtered model instead,
      # which comes to the same thing for a song's fixed set of links.
      def rebuild_external_links
        @external_link_tiles.each { |tile| external_links_box.remove(tile.root) }
        @external_link_tiles = handleable_links.map { |link| build_external_link_tile(link) }
        @external_link_tiles.each { |tile| external_links_box.append(tile.root) }
      end

      def handleable_links
        @song.then do |song|
          if song
            song.external_links.to_a.select { |link| ExternalLinkTile.can_handle?(link) }
          else
            []
          end
        end
      end

      def build_external_link_tile(link)
        ExternalLinkTile.new(link, on_launch_failed: @on_toast).tap(&:build)
      end

      def update_page_title
        @song&.artist_title_text.to_s.then do |title_text|
          root.title = title_text
          window_title.title = title_text
        end
      end

      def update_remove_button_sensitivity
        @song.then do |song|
          if song
            remove_button.sensitive = @song_list.contains?(song.id)
          else
            remove_button.sensitive = false
          end
        end
      end

      def update_album_cover_size
        if @adaptive_mode == :narrow
          album_cover.pixel_size = NARROW_ALBUM_COVER_PIXEL_SIZE
        else
          album_cover.pixel_size = NORMAL_ALBUM_COVER_PIXEL_SIZE
        end
      end
  end
end
