# frozen_string_literal: true

module Decidim
  module Tunnistamo
    # Provides compatibility with the privacy module.
    class UserFinder
      def self.find_by(**kwargs)
        query = Decidim::User
        query = query.entire_collection if query.respond_to?(:entire_collection)
        query.find_by(**kwargs)
      end
    end
  end
end
