# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module PrefixHelper
      def tunnistamo_prefix_hash
        @tunnistamo_prefix_hash ||= { value: "#{current_organization.reference_prefix}-", small: prefix_columns_small, medium: prefix_columns_medium }
      end

      private

      def prefix_columns_medium
        @prefix_columns_medium ||= begin
          prefix_columns_in_range(min: 1, max: 4, divider: 4)
        end
      end

      def prefix_columns_small
        @prefix_columns_small ||= begin
          prefix_columns_in_range(min: 2, max: 6, divider: 2)
        end
      end

      def prefix_columns_in_range(min: 1, max: 4, divider: 4)
        columns = reference_prefix_length / divider

        columns = min if columns < min
        columns = max if columns > max
        columns
      end

      def reference_prefix_length
        @reference_prefix_length ||= current_organization.reference_prefix.length
      end
    end
  end
end
