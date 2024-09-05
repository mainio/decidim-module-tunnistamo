# frozen_string_literal: true

require "spec_helper"

module Decidim
  module Tunnistamo
    describe OmniauthCallbacksController, type: :request do
      let(:organization) { create(:organization) }

      let(:uid) { SecureRandom.uuid }
      let(:email) { nil }
      let(:name) { "#{given_name} #{family_name}" }
      let(:given_name) { "Jack" }
      let(:family_name) { "Bauer" }
      let(:amr) { "google" }

      let(:oauth_hash) do
        {
          provider: "tunnistamo",
          uid: uid,
          info: {
            email: email,
            name: name,
            given_name: given_name,
            family_name: family_name,
            amr: amr
          },
          extra: {
            raw_info: {
              email: email,
              name: name,
              given_name: given_name,
              family_name: family_name,
              amr: amr
            }
          }
        }
      end

      before do
        OmniAuth.config.test_mode = true
        OmniAuth.config.add_mock(:tunnistamo, oauth_hash)

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
          let(:session) { nil }

          before do
            request_args = {}
            if session
              # Do a mock request in order to create a session
              get "/"
              session.each do |key, val|
                request.session[key.to_s] = val
              end
              request_args[:env] = {
                "rack.session" => request.session,
                "rack.session.options" => request.session.options
              }
            end

            get(
              "/users/auth/tunnistamo/callback?code=#{code}&state=#{state}",
              **request_args
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

          # Decidim core would want to redirect to the verifications path on the
          # first sign in but we don't want that to happen as the user is already
          # authorized during the sign in process.
          it "redirects to the root path by default after a successful registration and first sign in" do
            user = User.last

            expect(user.sign_in_count).to eq(1)
            expect(response).to redirect_to("/")
          end

          context "when the session has a pending redirect" do
            let(:session) { { user_return_to: "/processes" } }

            it "redirects to the stored location by default after a successful registration and first sign in" do
              user = User.last

              expect(user.sign_in_count).to eq(1)
              expect(response).to redirect_to("/processes")
            end
          end
        end

        context "when storing the email address" do
          let(:email) { "oauth.email@example.org" }
          let(:authenticator) do
            Decidim::Tunnistamo.authenticator_class.new(organization, oauth_hash)
          end

          before do
            allow(Decidim::Tunnistamo).to receive(:authenticator_for).and_return(authenticator)
          end

          context "when email is confirmed according to the authenticator" do
            before do
              allow(authenticator).to receive(:email_confirmed?).and_return(true)
            end

            it "creates the user account with the confirmed email address" do
              get(
                "/users/auth/tunnistamo/callback?code=#{code}&state=#{state}"
              )

              user = User.last
              expect(user.email).to eq(email)
              expect(user.unconfirmed_email).to be_nil
            end

            context "when the user is an admin with a pending password change request" do
              let!(:user) { create(:user, :admin, organization: organization, email: email, sign_in_count: 1, password_updated_at: 1.year.ago) }

              it "redirects to the password change path" do
                get(
                  "/users/auth/tunnistamo/callback?code=#{code}&state=#{state}"
                )

                expect(response).to redirect_to("/change_password")
              end
            end
          end

          context "when email is unconfirmed according to the authenticator" do
            before do
              allow(authenticator).to receive(:email_confirmed?).and_return(false)
            end

            it "creates the user account with the confirmed email address" do
              get(
                "/users/auth/tunnistamo/callback?code=#{code}&state=#{state}"
              )

              user = User.last
              expect(user.email).to match(/tunnistamo-[a-z0-9]{32}@[0-9]+.lvh.me/)
              expect(user.unconfirmed_email).to eq(email)
            end
          end
        end

        context "when user is signed in" do
          let(:session) { nil }
          let!(:confirmed_user) do
            create(:user, :confirmed, organization: organization)
          end

          before do
            request_args = {}
            if session
              # Do a mock request in order to create a session
              get "/"
              session.each do |key, val|
                request.session[key.to_s] = val
              end
              request_args[:env] = {
                "rack.session" => request.session,
                "rack.session.options" => request.session.options
              }
            end

            sign_in confirmed_user
            get(
              "/users/auth/tunnistamo/callback?code=#{code}&state=#{state}",
              **request_args
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

          it "redirects to the root path" do
            expect(response).to redirect_to("/")
          end

          context "when the session has a pending redirect" do
            let(:session) { { user_return_to: "/processes" } }

            it "redirects to the stored location" do
              expect(response).to redirect_to("/processes")
            end
          end
        end

        context "when identify with social media provider" do
          let(:confirmed_user) { create(:user, :confirmed, organization: organization) }
          let(:amr) { "google" }

          before do
            sign_in confirmed_user
            confirmed_user.remember_me!
            expect(confirmed_user.remember_created_at?).to be(true)
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
            expect(confirmed_user.remember_created_at?).to be(true)
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
