# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Tunnistamo
    describe EmailConfirmationsController, type: :controller do
      routes { Decidim::Tunnistamo::Engine.routes }

      let(:organization) { create(:organization) }
      let!(:user) { create(:user, organization: organization) }
      let(:email) { Faker::Internet.unique.email }

      before do
        allow(Decidim::Tunnistamo).to receive(:confirm_emails).and_return(true)
        request.env["decidim.current_organization"] = organization
      end

      context "when user is signed in" do
        before do
          sign_in user, scope: :user
        end

        describe "GET new" do
          it "renders new template" do
            get :new

            expect(subject).to render_template(:new)
          end
        end

        describe "POST create" do
          let(:params) { { email: email } }

          it "sends confirmation email and redirects" do
            post :create, params: params

            expect(Decidim::User.last.tunnistamo_email_sent_to).to eq(email)
            expect(response).to have_http_status(:redirect)
          end
        end

        describe "GET preview" do
          it "renders preview template" do
            get :preview

            expect(subject).to render_template(:preview)
          end
        end

        describe "POST confirm_with_code" do
          let(:code) { "00000" }

          before do
            allow(Decidim::Tunnistamo::SendConfirmationEmail).to receive(:create_code).and_return(code)
            user.update(tunnistamo_email_code: code, tunnistamo_email_code_sent_at: Time.current, tunnistamo_email_sent_to: email)
          end

          context "with right code" do
            let(:params) { { code: code } }

            it "confirms the user" do
              post :confirm_with_code, params: params

              expect(Decidim::User.last.confirmed_at).to be_between(1.minute.ago, Time.current)
              expect(flash[:notice]).to be_present
            end
          end

          context "with wrong code" do
            let(:params) { { code: "123456" } }

            it "doesnt confirm the user" do
              post :confirm_with_code, params: params

              expect(Decidim::User.last.confirmed_at).to be(nil)
              expect(flash[:alert]).to be_present
            end
          end
        end

        describe "POST confirm_with_token" do
          let(:params) do
            {
              user_id: user.id,
              confirmation_token: user.confirmation_token
            }
          end

          before do
            user.update(tunnistamo_email_code_sent_at: Time.current, tunnistamo_email_sent_to: email)
          end

          it "confirms the user" do
            post :confirm_with_token, params: params

            expect(Decidim::User.last.confirmed_at).to be_between(1.minute.ago, Time.current)
            expect(flash[:notice]).to be_present
          end
        end
      end

      context "when user is not logged in POST confirm_with_token" do
        let(:params) do
          {
            user_id: user.id,
            confirmation_token: user.confirmation_token
          }
        end

        context "and confirmation email is sent just now" do
          before do
            user.update(tunnistamo_email_code_sent_at: Time.current, tunnistamo_email_sent_to: email)
          end

          it "confirms the user" do
            post :confirm_with_token, params: params

            expect(Decidim::User.last.confirmed_at).to be_between(1.minute.ago, Time.current)
            expect(flash[:notice]).to be_present
          end
        end

        context "and confirmation email is expired" do
          before do
            user.update(tunnistamo_email_code_sent_at: 2.years.ago, tunnistamo_email_sent_to: email)
          end

          it "confirms the user" do
            post :confirm_with_token, params: params

            expect(Decidim::User.last.confirmed_at).to be(nil)
            expect(flash[:alert]).to be_present
          end
        end
      end

      context "when trying user_id doesnt match with token" do
        let!(:another_user) { create(:user, organization: organization) }

        let(:params) do
          {
            user_id: user.id,
            confirmation_token: another_user.confirmation_token
          }
        end

        before do
          another_user.update(tunnistamo_email_code_sent_at: Time.current, tunnistamo_email_sent_to: Faker::Internet.unique.email)
        end

        it "doesnt confirm users" do
          post :confirm_with_token, params: params

          expect(Decidim::User.first.confirmed_at).to be(nil)
          expect(Decidim::User.last.confirmed_at).to be(nil)
          expect(flash[:alert]).to be_present
        end
      end
    end
  end
end
