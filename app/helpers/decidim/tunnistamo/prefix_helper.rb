# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module PrefixHelper
      def prefix_columns
        @prefix_columns ||= begin
          return 1 if current_organization.reference_prefix.blank?

          prefix_columns = current_organization.reference_prefix.length / 4
          prefix_columns = 1 if prefix_columns.zero?
          prefix_columns = 4 if prefix_columns > 4
          prefix_columns
        end
      end
    end
  end
end
