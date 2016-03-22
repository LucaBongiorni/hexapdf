# -*- encoding: utf-8 -*-

module HexaPDF
  module Utils

    # Provides the convenience methods that are used for name trees and number trees.
    #
    # The provided methods require two methods defined in the including class so that they work
    # correctly:
    #
    # leaf_node_container_name::
    #   Defines the dictionary entry name that contains the leaf node entries.
    #
    #   For example, for name trees this would be :Names.
    #
    # key_type::
    #   Defines the class that is used for the keys in the tree.
    #
    #   The class defined this way is used for making sure that only valid keys are used.
    #
    #   For example, for name trees this would be String.
    #
    # See: HexaPDF::NameTreeNode, HexaPDF::NumberTreeNode
    module SortedTreeNode

      # :call-seq:
      #   tree.add_entry(key, data, overwrite: true)           -> true or false
      #
      # Adds a new tree entry (key-data pair) to the sorted tree and returns +true+ if it was
      # successfully added.
      #
      # If the option +overwrite+ is +true+, an existing entry is overwritten. Otherwise an error is
      # raised.
      #
      # This method has to be invoked on the root node of the tree!
      def add_entry(key, data, overwrite: true)
        if key?(:Limits)
          raise HexaPDF::Error, "Adding a new tree entry is only allowed via the root node"
        elsif !key.kind_of?(key_type)
          raise ArgumentError, "A key must be a #{key_type} object, not a #{key.class}"
        end

        container_name = leaf_node_container_name

        if (!key?(:Kids) && !key?(container_name)) ||
            (value[:Kids] && self[:Kids].empty?)
          value.delete(:Kids)
          value[container_name] = []
        end

        if key?(container_name)
          result = insert_pair(self[container_name], key, data, overwrite: overwrite)
          split_if_needed(self, self)
        else
          stack = []
          path_to_key(self, key, stack)

          result = insert_pair(stack.last[container_name], key, data, overwrite: overwrite)
          stack.last[:Limits] = stack.last[container_name].values_at(0, -2)
          stack.reverse_each.inject do |nested_node, node|
            nested_lower = nested_node[:Limits][0]
            nested_upper = nested_node[:Limits][1]
            if node[:Limits][0] > nested_lower
              node[:Limits][0] = nested_lower
            elsif node[:Limits][1] < nested_upper
              node[:Limits][1] = nested_upper
            end
            node
          end

          split_if_needed(stack[-2] || self, stack[-1])
        end

        result
      end

      # Deletes the entry specified by the +key+ from the tree and returns the data. If the tree
      # doesn't contain the key, +nil+ is returned.
      #
      # This method has to be invoked on the root node of the tree!
      def delete_entry(key)
        if key?(:Limits)
          raise HexaPDF::Error, "Deleting a tree entry is only allowed via the root node"
        end

        stack = [self]
        path_to_key(self, key, stack)
        container_name = leaf_node_container_name

        return unless stack.last[container_name]
        index = find_in_leaf_node(stack.last[container_name], key)
        return unless stack.last[container_name][index] == key

        value = stack.last[container_name].delete_at(index)
        document.delete(value) if value.kind_of?(HexaPDF::Object)
        value = stack.last[container_name].delete_at(index)

        stack.last[:Limits] = stack.last[container_name].values_at(0, -2) if stack.last[:Limits]

        stack.reverse_each.inject do |nested_node, node|
          if (!nested_node[container_name] || nested_node[container_name].empty?) &&
              (!nested_node[:Kids] || nested_node[:Kids].empty?)
            node[:Kids].delete_at(node[:Kids].index {|n| document.deref(n) == nested_node})
            document.delete(nested_node)
          end
          if node[:Kids].size > 0 && node[:Limits]
            node[:Limits][0] = document.deref(node[:Kids][0])[:Limits][0]
            node[:Limits][1] = document.deref(node[:Kids][-1])[:Limits][1]
          end
          node
        end

        value
      end

      # Finds and returns the associated entry for the key, or returns +nil+ if no such key is
      # found.
      def find_entry(key)
        container_name = leaf_node_container_name
        node = self
        result = nil

        while result.nil?
          if node.key?(container_name)
            index = find_in_leaf_node(node[container_name], key)
            if node[container_name][index] == key
              result = document.deref(node[container_name][index + 1])
            end
          elsif node.key?(:Kids)
            index = find_in_intermediate_node(node[:Kids], key)
            node = document.deref(node[:Kids][index])
            break unless key >= node[:Limits][0] && key <= node[:Limits][1]
          else
            break
          end
        end

        result
      end

      # :call-seq:
      #   node.each_entry {|key, data| block }   -> node
      #   node.each_entry                        -> Enumerator
      #
      # Calls the given block once for each entry (key-data pair) of the sorted tree.
      def each_entry(&block)
        return to_enum(__method__) unless block_given?

        container_name = leaf_node_container_name
        stack = [self]
        while !stack.empty?
          node = document.deref(stack.pop)
          if node.key?(container_name)
            data = node[container_name]
            index = 0
            while index < data.length
              yield(data[index], document.deref(data[index + 1]))
              index += 2
            end
          elsif node.key?(:Kids)
            stack.concat(node[:Kids].reverse)
          end
        end

        self
      end

      private

      # Starting from node traverses the tree to the node where the key is located or, if not
      # present, where it would be located and adds the nodes to the stack.
      def path_to_key(node, key, stack)
        return unless node.key?(:Kids)
        index = find_in_intermediate_node(node[:Kids], key)
        stack << document.deref(node[:Kids][index])
        path_to_key(stack.last, key, stack)
      end

      # Returns the index into the /Kids array where the entry for +key+ is located or, if not
      # present, where it would be located.
      def find_in_intermediate_node(array, key)
        left = 0
        right = array.length - 1
        while left < right
          mid = (left + right) / 2
          limits = document.deref(array[mid])[:Limits]
          if limits[1] < key
            left = mid + 1
          elsif limits[0] > key
            right = mid - 1
          else
            left = right = mid
          end
        end
        left
      end

      # Inserts the key-data pair into array at the correct position and returns +true+ if the
      # key-data pair was successfully inserted.
      #
      # An existing entry for the key is only overwritten if the option +overwrite+ is +true+.
      def insert_pair(array, key, data, overwrite: true)
        index = find_in_leaf_node(array, key)
        return false if array[index] == key && !overwrite

        if array[index] == key
          array[index + 1] = data
        else
          array.insert(index, key, data)
        end

        true
      end

      # Returns the index into the array where the entry for +key+ is located or, if not present,
      # where it would be located.
      def find_in_leaf_node(array, key)
        left = 0
        right = array.length - 1
        while left <= right
          mid = ((left + right) / 2) & ~1 # mid must be even because of [key val key val...]
          if array[mid] < key
            left = mid + 2
          elsif array[mid] > key
            right = mid - 2
          else
            left = mid
            right = left - 1
          end
        end
        left
      end

      # Splits the leaf node if it contains the maximum number of entries.
      def split_if_needed(parent, leaf_node)
        container_name = leaf_node_container_name
        max_size = config['sorted_tree.max_leaf_node_size'] * 2
        return unless leaf_node[container_name].size >= max_size

        split_point = (max_size / 2) & ~1
        if parent == leaf_node
          node1 = document.add(document.wrap({}, type: self.class))
          node2 = document.add(document.wrap({}, type: self.class))
          node1[container_name] = leaf_node[container_name][0, split_point]
          node1[:Limits] = node1[container_name].values_at(0, -2)
          node2[container_name] = leaf_node[container_name][split_point..-1]
          node2[:Limits] = node2[container_name].values_at(0, -2)
          parent.delete(container_name)
          parent[:Kids] = [node1, node2]
        else
          node1 = document.add(document.wrap({}, type: self.class))
          node1[container_name] = leaf_node[container_name].slice!(split_point..-1)
          node1[:Limits] = node1[container_name].values_at(0, -2)
          leaf_node[:Limits][1] = leaf_node[container_name][-2]
          index = 1 + parent[:Kids].index {|o| document.deref(o) == leaf_node}
          parent[:Kids].insert(index, node1)
        end
      end

      # Validates the sorted tree node.
      def perform_validation
        super
        container_name = leaf_node_container_name

        # All kids entries must be indirect objects
        if key?(:Kids)
          self[:Kids].each do |kid|
            unless (kid.kind_of?(HexaPDF::Object) && kid.indirect?) ||
                kid.kind_of?(HexaPDF::Reference)
              yield("Child entries of sorted tree nodes must be indirect objects", false)
            end
          end
        end

        # All keys of the container must be lexically ordered strings and the container must be
        # correctly formatted
        if key?(container_name)
          container = self[container_name]
          if container.length.odd?
            yield("Sorted tree leaf node contains odd number of entries", false)
          end
          index = 0
          old = nil
          while index < container.length
            key = document.unwrap(container[index])
            if !key.kind_of?(key_type)
              yield("A key must be a #{key_type} object, not a #{key.class}", false)
            elsif old && old > key
              yield("Sorted tree leaf node entries are not correctly sorted", false)
            end
            old = key
            index += 2
          end
        end
      end

    end

  end
end
