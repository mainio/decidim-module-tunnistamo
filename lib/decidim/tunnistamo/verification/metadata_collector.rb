# frozen_string_literal: true

module Decidim
  module Tunnistamo
    module Verification
      class MetadataCollector
        def initialize(raw_info)
          @raw_info = raw_info
        end

        def metadata
          {
            name: raw_info[:name],
            given_name: raw_info[:given_name],
            family_name: raw_info[:family_name],
            birthdate: raw_info[:birthdate]
          }
        end

        protected

        attr_reader :raw_info
      end
    end
  end
end
