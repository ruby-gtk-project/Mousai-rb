# frozen_string_literal: true

module Mousai
  # Ported from upstream's src/utils.rs. Upstream's `spawn` helper has no
  # counterpart here — the port has no futures to spawn — so this is the
  # grouping helper the song list uses when it removes a selection.
  module Utils
    module_function

    # Returns a list of `[first, count]` pairs where `first` is the first
    # number in a consecutive group and `count` is how many numbers that group
    # holds. The input is treated as a set: it is sorted and deduplicated
    # first, matching upstream's `BTreeSet` parameter.
    def consecutive_groups(numbers)
      numbers.to_a.uniq.sort.each_with_object([]) do |number, groups|
        groups.last.then do |group|
          if group && group[0] + group[1] == number
            group[1] += 1
          else
            groups << [number, 1]
          end
        end
      end
    end
  end
end
