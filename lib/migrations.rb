# frozen_string_literal: true

module Mousai
  # The database's migration runner.
  #
  # Ported from upstream's src/database/migrations.rs: migrations are added in
  # order with a name, the database carries the version it has reached, and a
  # run executes every migration whose version is above that and records the
  # new version as it goes, so an interrupted run resumes where it stopped.
  class Migrations
    Migration = Struct.new(:name, :func)

    def initialize
      @migrations = []
    end

    # Adds a migration. Upstream debug-asserts that names are unique; a
    # duplicate name here is a programming error and raises.
    def add(name, &func)
      if @migrations.any? { |migration| migration.name == name }
        raise(ArgumentError, "there must be no duplicate migration names, got `#{name}` twice")
      end

      @migrations << Migration.new(name, func)
      self
    end

    def max_version = @migrations.length

    # Runs the pending migrations against the database, inside one write.
    def run(database)
      database.user_version.then do |current_version|
        unless max_version == current_version
          database.with_write { run_pending(database, current_version) }
        end
      end
    end

    private

      def run_pending(database, current_version)
        @migrations.each_with_index do |migration, index|
          (index + 1).then do |migration_version|
            if migration_version > current_version
              migration.func.call(database)
              database.user_version = migration_version
            end
          end
        end
      end
  end
end
