# frozen_string_literal: true

module Mousai
  # The error raised when a task was cancelled rather than failing.
  #
  # Ported from upstream's src/cancelled.rs, which is an `std::error::Error`
  # carrying the name of the cancelled task and displaying as
  # "Cancelled <task>".
  class Cancelled < StandardError
    attr_reader :task

    def initialize(task)
      @task = task.to_s
      super("Cancelled #{@task}")
    end
  end
end
