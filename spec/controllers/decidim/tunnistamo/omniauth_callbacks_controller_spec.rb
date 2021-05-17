# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Tunnistamo
    describe OmniauthCallbacksController, type: :request do
      let(:organization) { create(:organization) }

      let(:uid) { SecureRandom.uuid }
      let(:name) { "#{given_name} #{family_name}" }
      let(:given_name) { "Jack" }
      let(:family_name) { "Bauer" }
      let(:amr) { "google" }

      before do
        OmniAuth.config.test_mode = true
        OmniAuth.config.add_mock(:tunnistamo,
                                 uid: uid,
                                 info: {
                                   name: name,
                                   given_name: given_name,
                                   family_name: family_name,
                                   amr: amr
                                 },
                                 extra: {
                                   raw_info: {
                                     name: name,
                                     given_name: given_name,
                                     family_name: family_name,
                                     amr: amr
                                   }
                                 })

        # Make the time validation of the SAML response work properly
        allow(Time).to receive(:now).and_return(
          Time.utc(2019, 8, 14, 22, 35, 0)
        )

        # Set the correct host
        host! organization.host
      end

      describe "GET /users/auth/tunnistamo/callback" do
        let(:code) { SecureRandom.hex(16) }
        let(:state) { SecureRandom.hex(16) }

        context "when user isn't signed in" do
          before do
            get(
              "/users/auth/tunnistamo/callback?code=#{code}&state=#{state}"
            )
          end

          it "creates authorization" do
            authorization = Decidim::Authorization.last
            expect(authorization).not_to be_nil
            expect(authorization.name).to eq("tunnistamo_idp")
            expect(authorization.metadata["name"]).to eq(name)
            expect(authorization.metadata["service"]).to eq(amr)
            expect(authorization.metadata["given_name"]).to eq(given_name)
            expect(authorization.metadata["family_name"]).to eq(family_name)
          end
        end

        context "when user is signed in" do
          let!(:confirmed_user) do
            create(:user, :confirmed, organization: organization)
          end

          before do
            sign_in confirmed_user
            get(
              "/users/auth/tunnistamo/callback?code=#{code}&state=#{state}"
            )
          end

          it "identifies user" do
            authorization = Authorization.find_by(
              user: confirmed_user,
              name: "tunnistamo_idp"
            )

            expect(authorization).not_to be_nil
            expect(authorization.user).to eq(confirmed_user)
          end
        end

        context "when identify with social media provider" do
          let(:confirmed_user) { create(:user, :confirmed, organization: organization) }
          let(:amr) { "google" }

          before do
            sign_in confirmed_user
            confirmed_user.remember_me!
            expect(confirmed_user.remember_created_at?).to eq(true)
            get(
              "/users/auth/tunnistamo/callback?code=#{code}&state=#{state}"
            )
          end

          it "forgets user's remember me" do
            authorization = Decidim::Authorization.last
            expect(authorization.metadata["service"]).to eq("google")
            expect(authorization.user.remember_created_at).to be_between(1.minute.ago, Time.current)
          end
        end

        context "when there is strong providers" do
          let(:confirmed_user) { create(:user, :confirmed, organization: organization) }
          let(:amr) { "suomifi" }

          before do
            allow(Decidim::Tunnistamo).to receive(:strong_identity_providers).and_return(%w(espoo suomifi))
            sign_in confirmed_user
            confirmed_user.remember_me!
            expect(confirmed_user.remember_created_at?).to eq(true)
            get(
              "/users/auth/tunnistamo/callback?code=#{code}&state=#{state}"
            )
          end

          it "forgets user's remember me" do
            authorization = Decidim::Authorization.last
            expect(authorization.metadata["service"]).to eq("suomifi")
            expect(authorization.user.remember_created_at).to be_nil
          end
        end

        context "when identity is bound to another user" do
          let(:confirmed_user) { create(:user, :confirmed, organization: organization) }
          let(:another_user) { create(:user, :confirmed, organization: organization) }
          let!(:identity) { create(:identity, user: another_user, provider: "tunnistamo", uid: uid, organization: organization) }

          before do
            sign_in confirmed_user
            get(
              "/users/auth/tunnistamo/callback?code=#{code}&state=#{state}"
            )
          end

          it "identifies user" do
            authorization = Authorization.find_by(
              user: confirmed_user,
              name: "tunnistamo_idp"
            )
            expect(authorization).to be_nil
            expect(response).to redirect_to("/users/auth/tunnistamo/logout")
            expect(flash[:alert]).to eq(
              "Another user has already been identified using this identity. Please sign out and sign in again directly using Tunnistamo."
            )
          end
        end
      end
    end
  end
end
