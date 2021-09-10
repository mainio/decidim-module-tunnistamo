# frozen_string_literal: true

module Decidim
  module Tunnistamo
    class EmailConfirmationsController < Decidim::ApplicationController
      include Decidim::FormFactory

      skip_before_action :store_current_location

      def new
        @form = ::Decidim::Tunnistamo::EmailConfirmationForm.new(email: current_user.email)
      end

      def create
        @form = form(::Decidim::Tunnistamo::EmailConfirmationForm).from_params(params)

        ::Decidim::Tunnistamo::CreateEmailConfirmation.call(@form, current_user) do
          on(:ok) do
            redirect_to preview_email_confirmation_path, email: @form.email
          end

          on(:invalid) do
            flash.now[:alert] = "create error"
            render :new
          end
        end
      end

      def preview
        @form = form(::Decidim::Tunnistamo::CodeConfirmationForm).from_params(params)
        render :preview
      end

      def complete
        @form = form(::Decidim::Tunnistamo::CodeConfirmationForm).from_params(params)

        ::Decidim::Tunnistamo::ConfirmEmail.call(@form, current_user) do |new_email|
          on(:ok) do
            flash[:notice] = "Success #{new_email}"
            redirect_to decidim.root_path
          end

          on(:invalid) do
            flash.now[:alert] = "update error"
            render :preview
          end
        end
      end
    end
  end
end
