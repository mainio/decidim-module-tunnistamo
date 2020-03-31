# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class SessionsController < ::Decidim::Devise::SessionsController
      def tunnistamo_logout
        # This is handled already by OmniAuth
        redirect_to decidim.root_path
      end
    end
  end
end
