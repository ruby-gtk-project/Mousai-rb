# frozen_string_literal: true

require "adwaita"
require_relative "i18n"
require_relative "lyrics_page"
require_relative "song"
require_relative "song_filter"
require_relative "song_list"
require_relative "song_page"
require_relative "song_tile"

module Mousai
  # The main view: the history grid, its search, its selection mode, and the
  # navigation stack the song and lyrics pages are pushed onto.
  #
  # Ported from upstream's src/window/history_view.rs and
  # data/resources/ui/history_view.ui, including the two menus the UI file
  # defines (`menu` and `selection_menu`), the two empty states
  # (`content_empty_page` and `content_empty_search_result_page`) and the undo
  # toast from `show_undo_remove_song_toast`.
  #
  # Upstream also hosts the recognizer status in its header bar and pushes a
  # RecognizedPage when a recognition finishes; neither is ported yet, so the
  # header bar carries the rest of its buttons and nothing claims to listen.
  class HistoryView
    APP_ICON_NAME = "io.github.seadve.Mousai"

    attr_reader :song_list

    def initialize(song_list:, on_toast: nil, on_message_toast: nil)
      @song_list = song_list
      @on_toast = on_toast
      @on_message_toast = on_message_toast
      @selection_mode_active = false
      @adaptive_mode = :normal
      @songs_purgatory = []
      @undo_remove_song_toast = nil
      @tiles = {}
      @selection_mode_listeners = []
      @song_list.on_items_changed { update_content_stack_visible_child }
    end

    def build
      root.tap do |nav_view|
        nav_view.add(main_page)

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar_stack)
          view.add_top_bar(search_bar)
          view.add_bottom_bar(selection_mode_bar)
          view.content = content_stack

          header_bar_stack.tap do |stack|
            stack.add_child(main_header_bar)
            stack.add_child(selection_mode_header_bar)

            main_header_bar.tap do |bar|
              bar.pack_start(listen_button)
              bar.pack_end(main_menu_button)
              bar.pack_end(select_button)
              bar.pack_end(search_button)
            end

            selection_mode_header_bar.tap do |bar|
              bar.title_widget = selection_mode_menu_button
              bar.pack_end(cancel_selection_button)
              bar.pack_end(selection_mode_search_button)
            end
          end

          search_bar.tap do |bar|
            bar.child = search_entry
            bar.connect_entry(search_entry)

            search_entry.tap do |entry|
              entry.signal_connect("search-changed") { on_search_changed }
            end
          end

          content_stack.tap do |stack|
            stack.add_child(content_main_page)
            stack.add_child(content_empty_page)
            stack.add_child(content_empty_search_result_page)

            content_main_page.tap do |scroller|
              scroller.child = grid
            end
          end

          selection_mode_bar.tap do |bar|
            bar.pack_start(copy_selected_songs_button)
            bar.pack_start(remove_selected_songs_button)
          end
        end

        root.signal_connect("popped") { |_, page| forget_page(page) }

        grid.tap do |grid_view|
          grid_view.model = selection_model
          grid_view.factory = grid_factory

          grid_view.signal_connect("activate") do |_, position|
            push_song_page(song_at(position))
          end
        end

        [search_button, selection_mode_search_button].each do |button|
          search_bar.bind_property(
            "search-mode-enabled",
            button,
            "active",
            GLib::BindingFlags::SYNC_CREATE | GLib::BindingFlags::BIDIRECTIONAL,
          )
        end

        root.insert_action_group("history-view", action_group)
      end.tap do
        update_selection_actions
        update_selection_mode_ui
        update_content_stack_visible_child
      end
    end

    # The search bar, which the window gives its key capture widget and toggles
    # from `win.toggle-search`.
    def search_bar
      @search_bar ||= Gtk::SearchBar.new.tap do |bar|
        bar.show_close_button = false
      end
    end

    def selection_mode_active? = @selection_mode_active
    def stop_selection_mode = self.selection_mode_active = false

    def on_selection_mode_changed(&block)
      @selection_mode_listeners << block
      block
    end

    def adaptive_mode=(mode)
      mode.then do |adaptive_mode|
        unless adaptive_mode == @adaptive_mode
          @adaptive_mode = adaptive_mode
          @tiles.each_value { |tile| tile.adaptive_mode = adaptive_mode }
          song_pages.each { |page| page.adaptive_mode = adaptive_mode }
        end
      end
    end

    def on_navigation_main_page? = root.visible_page == main_page

    # Pushes a song page for the given song, unless that song's page is already
    # the visible one.
    def push_song_page(song)
      song.then do |target|
        unless target.nil? || showing_song_page_for?(target)
          root.push(new_song_page(target).root)
          # The user is now aware of the newly recognized song, so unset it.
          target.newly_heard = false
        end
      end
    end

    # Pushes the lyrics page for the given song, unless it is already visible.
    def push_lyrics_page(song)
      song.then do |target|
        unless target.nil? || showing_lyrics_page_for?(target)
          root.push(new_lyrics_page(target).root)
        end
      end
    end

    def pop_page = root.pop

    def scroll_to_top = content_main_page.emit("scroll-child", Gtk::ScrollType::START, false)

    def root = @root ||= Adwaita::NavigationView.new
    def main_page = @main_page ||= Adwaita::NavigationPage.new(toolbar_view, I18n.gettext("Home"))
    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar_stack
      @header_bar_stack ||= Gtk::Stack.new.tap do |stack|
        stack.transition_type = :crossfade
      end
    end

    def main_header_bar = @main_header_bar ||= Adwaita::HeaderBar.new

    # Upstream's Listen button drives `win.toggle-recognize`. The recognizer is
    # not ported yet, so no window installs that action and GTK keeps the
    # button insensitive — which is the honest state for it.
    def listen_button
      @listen_button ||= Gtk::Button.new(label: I18n.gettext("Listen")).tap do |button|
        button.tooltip_text = I18n.gettext("Recognize Song")
        button.action_name = "win.toggle-recognize"
        button.add_css_class("suggested-action")
      end
    end

    def main_menu_button
      @main_menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.tooltip_text = I18n.gettext("Main Menu")
        button.icon_name = "open-menu-symbolic"
        button.menu_model = menu
        button.primary = true
      end
    end

    def select_button
      @select_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = I18n.gettext("Select")
        button.icon_name = "selection-mode-symbolic"
        button.action_name = "history-view.toggle-selection-mode"
      end
    end

    def search_button
      @search_button ||= Gtk::ToggleButton.new.tap do |button|
        button.tooltip_text = I18n.gettext("Search Songs")
        button.icon_name = "system-search-symbolic"
      end
    end

    def selection_mode_header_bar = @selection_mode_header_bar ||= Adwaita::HeaderBar.new

    def selection_mode_menu_button
      @selection_mode_menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.menu_model = selection_menu
      end
    end

    def cancel_selection_button
      @cancel_selection_button ||= Gtk::Button.new(label: I18n.gettext("Cancel")).tap do |button|
        button.tooltip_text = I18n.gettext("Cancel Selection")
        button.action_name = "history-view.toggle-selection-mode"
      end
    end

    def selection_mode_search_button
      @selection_mode_search_button ||= Gtk::ToggleButton.new.tap do |button|
        button.tooltip_text = I18n.gettext("Search Songs")
        button.icon_name = "system-search-symbolic"
      end
    end

    # The main menu of data/resources/ui/history_view.ui (menu id="menu").
    def menu
      @menu ||= Gio::Menu.new.tap do |model|
        model.append(I18n.gettext("_Preferences"), "app.show-preferences")
        model.append(I18n.gettext("_Keyboard Shortcuts"), "app.shortcuts")
        model.append(I18n.gettext("_About Mousai"), "app.show-about")
      end
    end

    # The selection menu of the same file (menu id="selection_menu").
    def selection_menu
      @selection_menu ||= Gio::Menu.new.tap do |model|
        model.append(I18n.gettext("Select _All"), "history-view.select-all")
        model.append(I18n.gettext("_Unselect All"), "history-view.select-none")
      end
    end

    def search_entry
      @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.placeholder_text = I18n.gettext("Search songs")
      end
    end

    def content_stack
      @content_stack ||= Gtk::Stack.new.tap do |stack|
        stack.transition_type = :crossfade
      end
    end

    def content_main_page
      @content_main_page ||= Gtk::ScrolledWindow.new.tap do |scroller|
        scroller.hscrollbar_policy = :never
      end
    end

    def grid
      @grid ||= Gtk::GridView.new.tap do |grid_view|
        grid_view.min_columns = 2
        grid_view.add_css_class("history-view")
      end
    end

    # The empty state shown while the history is empty.
    def content_empty_page
      @content_empty_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = APP_ICON_NAME
        page.title = I18n.gettext("Start Recognizing Songs!")
        page.description = I18n.gettext("Click the listen button to start")
        page.add_css_class("icon-dropshadow")
      end
    end

    # The empty state shown while a search matches nothing.
    def content_empty_search_result_page
      @content_empty_search_result_page ||= Adwaita::StatusPage.new.tap do |page|
        page.icon_name = "system-search-symbolic"
        page.title = I18n.gettext("No Results")
      end
    end

    def selection_mode_bar = @selection_mode_bar ||= Gtk::ActionBar.new

    def copy_selected_songs_button
      @copy_selected_songs_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "edit-copy-symbolic"
        button.action_name = "history-view.copy-selected-song"
      end
    end

    def remove_selected_songs_button
      @remove_selected_songs_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = "user-trash-symbolic"
        button.action_name = "history-view.remove-selected-songs"
      end
    end

    def song_filter = @song_filter ||= SongFilter.new

    def filter_model
      @filter_model ||= Gtk::FilterListModel.new(@song_list.list_store, song_filter.filter).tap do |model|
        model.signal_connect("items-changed") { update_content_stack_visible_child }
      end
    end

    def selection_model
      @selection_model ||= Gtk::MultiSelection.new(filter_model).tap do |model|
        model.signal_connect("selection-changed") { on_selection_changed }
        model.signal_connect("items-changed") { on_selection_changed }
      end
    end

    # One tile per visible row, kept per list item so bind and unbind can find
    # the tile the row is showing.
    def grid_factory
      @grid_factory ||= Gtk::SignalListItemFactory.new.tap do |factory|
        factory.signal_connect("setup") { |_, item| setup_list_item(item) }
        factory.signal_connect("bind") { |_, item| bind_list_item(item) }
        factory.signal_connect("unbind") { |_, item| unbind_list_item(item) }
        factory.signal_connect("teardown") { |_, item| @tiles.delete(item.object_id) }
      end
    end

    def action_group
      @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
        group.add_action(toggle_selection_mode_action)
        group.add_action(select_all_action)
        group.add_action(select_none_action)
        group.add_action(copy_selected_song_action)
        group.add_action(remove_selected_songs_action)
      end
    end

    def toggle_selection_mode_action
      @toggle_selection_mode_action ||= Gio::SimpleAction.new("toggle-selection-mode").tap do |action|
        action.signal_connect("activate") { toggle_selection_mode }
      end
    end

    def select_all_action
      @select_all_action ||= Gio::SimpleAction.new("select-all").tap do |action|
        action.signal_connect("activate") { selection_model.select_all }
      end
    end

    def select_none_action
      @select_none_action ||= Gio::SimpleAction.new("select-none").tap do |action|
        action.signal_connect("activate") { selection_model.unselect_all }
      end
    end

    def copy_selected_song_action
      @copy_selected_song_action ||= Gio::SimpleAction.new("copy-selected-song").tap do |action|
        action.signal_connect("activate") { copy_selected_songs }
      end
    end

    def remove_selected_songs_action
      @remove_selected_songs_action ||= Gio::SimpleAction.new("remove-selected-songs").tap do |action|
        action.signal_connect("activate") { remove_selected_songs }
      end
    end

    private

      def song_pages = @song_pages ||= []

      # Upstream reads `is_selection_mode_active` before unselecting, because
      # the selection change callback also turns selection mode off; doing it
      # in the other order flickers.
      def toggle_selection_mode
        @selection_mode_active.then do |was_active|
          selection_model.unselect_all
          self.selection_mode_active = !was_active
        end
      end

      def selection_mode_active=(value)
        value.then do |active|
          unless active == @selection_mode_active
            @selection_mode_active = active
            @tiles.each_value { |tile| tile.selection_mode_active = active }
            update_selection_mode_ui
            update_selection_actions
            @selection_mode_listeners.each { |listener| listener.call(self) }
          end
        end
      end

      def on_selection_changed
        if @selection_mode_active
          if selected_positions.empty?
            self.selection_mode_active = false
          end

          update_selection_actions
          refresh_tile_selection
        end
      end

      def on_search_changed
        search_entry.text.strip.then do |text|
          song_filter.search = text
          @song_list.sorter.search = text
          update_content_stack_visible_child
        end
      end

      def selected_positions
        (0...selection_model.n_items).select { |position| selection_model.selected?(position) }
      end

      def song_at(position)
        selection_model.get_item(position).then do |item|
          item && @song_list.get(item.id)
        end
      end

      def snapshot_selected_songs = selected_positions.filter_map { |position| song_at(position) }

      def copy_selected_songs
        snapshot_selected_songs.then do |songs|
          unless songs.empty?
            root.display.clipboard.set_text(songs.map(&:artist_title_text).join("\n"))
            @on_message_toast&.call(I18n.gettext("Copied to clipboard"))
          end
        end
      end

      def remove_selected_songs
        snapshot_selected_songs.then do |songs|
          unless songs.empty?
            remove_songs(songs.map(&:id))
            show_undo_remove_song_toast
          end
        end
      end

      # Removed songs go to the purgatory the undo toast empties back into the
      # history.
      def remove_songs(song_ids)
        @songs_purgatory.concat(@song_list.remove_many(song_ids))
      end

      # Ported from upstream's `show_undo_remove_song_toast`: one toast, whose
      # title counts everything in the purgatory and whose timeout is reset by
      # sending it again.
      def show_undo_remove_song_toast
        unless @undo_remove_song_toast
          @undo_remove_song_toast = Adwaita::Toast.new("").tap do |toast|
            toast.priority = :high
            toast.button_label = I18n.gettext("_Undo")
            toast.signal_connect("button-clicked") { undo_remove_songs }
            toast.signal_connect("dismissed") { forget_removed_songs }
          end
        end

        @undo_remove_song_toast.title = removed_songs_message
        @on_toast&.call(@undo_remove_song_toast)
      end

      def removed_songs_message
        @songs_purgatory.length.then do |n_removed|
          I18n.ngettext_f(
            # Translators: Do NOT translate the contents between '{' and '}', this is a variable name.
            "Removed {n_removed} song",
            "Removed {n_removed} songs",
            n_removed,
            { "n_removed" => n_removed },
          )
        end
      end

      def undo_remove_songs
        @song_list.insert_many(@songs_purgatory)
        @songs_purgatory = []
      end

      def forget_removed_songs
        @songs_purgatory = []
        @undo_remove_song_toast = nil
      end

      def update_selection_mode_ui
        if @selection_mode_active
          header_bar_stack.visible_child = selection_mode_header_bar
          grid.grab_focus
        else
          header_bar_stack.visible_child = main_header_bar
        end

        selection_mode_bar.revealed = @selection_mode_active
        grid.enable_rubberband = @selection_mode_active
        grid.single_click_activate = !@selection_mode_active
      end

      def update_selection_actions
        selected_positions.length.then do |selection_size|
          copy_selected_song_action.enabled = !selection_size.zero?
          remove_selected_songs_action.enabled = !selection_size.zero?
          selection_mode_menu_button.label = selection_label(selection_size)
          copy_selected_songs_button.tooltip_text =
            I18n.ngettext("Copy Song", "Copy Songs", selection_size)
          remove_selected_songs_button.tooltip_text = I18n.ngettext(
            "Remove Song From History",
            "Remove Songs From History",
            selection_size,
          )
        end
      end

      def selection_label(selection_size)
        if selection_size.zero?
          I18n.gettext("Select items")
        else
          I18n.ngettext_f(
            # Translators: Do NOT translate the contents between '{' and '}', this is a variable name.
            "Selected {selection_size} song",
            "Selected {selection_size} songs",
            selection_size,
            { "selection_size" => selection_size },
          )
        end
      end

      # Which of the three content pages is shown: the search's empty state
      # while a search matches nothing, the history's empty state while there
      # is no history, and the grid otherwise.
      def update_content_stack_visible_child
        if filter_model.n_items.zero? && !search_entry.text.empty?
          content_stack.visible_child = content_empty_search_result_page
        elsif @song_list.empty? && search_entry.text.empty?
          content_stack.visible_child = content_empty_page
        else
          content_stack.visible_child = content_main_page
        end
      end

      def setup_list_item(item)
        SongTile.new(shows_select_button_on_hover: true).then do |tile|
          @tiles[item.object_id] = tile
          tile.selection_mode_active = @selection_mode_active
          tile.adaptive_mode = @adaptive_mode
          tile.on_selection_mode_requested { self.selection_mode_active = true }
          tile.on_active_changed { |changed| apply_tile_selection(item, changed) }
          item.child = tile.build
        end
      end

      def bind_list_item(item)
        @tiles[item.object_id].then do |tile|
          if tile
            tile.song = @song_list.get(item.item.id)
            tile.selected = item.selected? && @selection_mode_active
          end
        end
      end

      def unbind_list_item(item)
        @tiles[item.object_id]&.song = nil
      end

      # The tick in a tile is the row's selection: ticking one selects the row,
      # unticking it unselects it.
      def apply_tile_selection(item, tile)
        if tile.active?
          selection_model.select_item(item.position, false)
        else
          selection_model.unselect_item(item.position)
        end
      end

      def refresh_tile_selection
        @tiles.each_value do |tile|
          tile.selected = tile.selected? && @selection_mode_active
        end
      end

      # A popped page is gone for good — upstream keeps it on a forward stack so
      # a swipe forward can restore it, which needs the navigation view's
      # `get-next-page` signal to return a page; the Ruby bindings give a
      # handler no way to do that, so the page is dropped instead.
      def forget_page(page)
        song_pages.reject! { |song_page| song_page.root == page }
        lyrics_pages.reject! { |lyrics_page| lyrics_page.root == page }
      end

      def showing_song_page_for?(song)
        song_pages.find { |page| page.root == root.visible_page }.then do |page|
          page && page.song&.id == song.id
        end
      end

      def showing_lyrics_page_for?(song)
        lyrics_pages.find { |page| page.root == root.visible_page }.then do |page|
          page && page.song&.id == song.id
        end
      end

      def lyrics_pages = @lyrics_pages ||= []

      def new_song_page(song)
        SongPage.new(song_list: @song_list, on_toast: @on_message_toast).tap do |page|
          page.build
          page.song = song
          page.adaptive_mode = @adaptive_mode
          page.on_song_remove_request { |requesting| remove_song_of(requesting) }
          page.on_show_lyrics_request { |requesting| push_lyrics_page(requesting.song) }
          song_pages << page
        end
      end

      def remove_song_of(page)
        page.song.then do |song|
          if song
            remove_songs([song.id])
            show_undo_remove_song_toast
          end
        end
      end

      def new_lyrics_page(song)
        LyricsPage.new.tap do |page|
          page.build
          page.song = song
          lyrics_pages << page
        end
      end
  end
end
