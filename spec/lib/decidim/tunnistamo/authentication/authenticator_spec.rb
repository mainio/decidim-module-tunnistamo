# frozen_string_literal: true

require "spec_helper"

describe Decidim::Tunnistamo::Authentication::Authenticator do
  subject { described_class.new(organization, oauth_hash) }

  let(:organization) { create(:organization) }
  let(:oauth_hash) do
    {
      provider: oauth_provider,
      uid: oauth_uid,
      info: oauth_info,
      extra: {
        raw_info: oauth_raw_info
      }
    }
  end
  let(:oauth_provider) { "provider" }
  let(:oauth_uid) { "uid" }
  let(:oauth_name) { "Marja Mainio" }
  let(:oauth_image) { nil }
  let(:oauth_info) do
    {
      name: oauth_name,
      image: oauth_image
    }
  end
  let(:oauth_raw_info) do
    {
      name: "Marja Mirja Mainio",
      given_name: "Marja",
      family_name: "Mainio",
      birthdate: "1985-07-15",
      amr: "google"

    }
  end

  describe "#verified_email" do
    context "when email is available in the SAML attributes" do
      let(:oauth_info) { { email: "user@example.org" } }

      it "returns the email from SAML attributes" do
        expect(subject.verified_email).to eq("user@example.org")
      end

      context "and confirm_emails is forced" do
        before do
          allow(Decidim::Tunnistamo).to receive(:confirm_emails).and_return(true)
        end

        it "returns the generated email" do
          expect(subject.verified_email).to match(/tunnistamo-[a-z0-9]{32}@[0-9]+.lvh.me/)
        end
      end
    end

    context "when email is not available in the SAML attributes" do
      it "auto-creates the email using the known pattern" do
        expect(subject.verified_email).to match(/tunnistamo-[a-z0-9]{32}@[0-9]+.lvh.me/)
      end

      context "and auto_email_domain is not defined" do
        before do
          allow(Decidim::Tunnistamo).to receive(:auto_email_domain).and_return(nil)
        end

        it "auto-creates the email using the known pattern" do
          expect(subject.verified_email).to match(/tunnistamo-[a-z0-9]{32}@#{organization.host}/)
        end
      end
    end
  end

  describe "#user_params_from_oauth_hash" do
    shared_examples_for "expected hash" do
      it "returns the expected hash" do
        signature = ::Decidim::OmniauthRegistrationForm.create_signature(
          oauth_provider,
          oauth_uid
        )

        expect(subject.user_params_from_oauth_hash).to include(
          provider: oauth_provider,
          uid: oauth_uid,
          name: "Marja Mainio",
          oauth_signature: signature,
          avatar_url: nil,
          raw_data: oauth_hash
        )
      end
    end

    it_behaves_like "expected hash"

    context "when oauth data info doesnt include name" do
      let(:oauth_info) do
        {
          image: oauth_image
        }
      end
      let(:oauth_raw_info) do
        {
          name: "Marja Mirja Mainio",
          given_name: "Marja",
          family_name: "Mainio",
          birthdate: "1985-07-15",
          amr: "google"

        }
      end

      it_behaves_like "expected hash"
    end

    context "when oauth data is empty" do
      let(:oauth_hash) { {} }

      it "returns nil" do
        expect(subject.user_params_from_oauth_hash).to be_nil
      end
    end

    context "when user identifier is blank" do
      let(:oauth_uid) { nil }

      it "returns nil" do
        expect(subject.user_params_from_oauth_hash).to be_nil
      end
    end
  end

  describe "#validate!" do
    it "returns true for valid authentication data" do
      expect(subject.validate!).to be(true)
    end
  end

  describe "#identify_user!" do
    let(:user) { create(:user, :confirmed, organization: organization) }

    it "creates a new identity for the user" do
      id = subject.identify_user!(user)

      expect(Decidim::Identity.count).to eq(1)
      expect(Decidim::Identity.last.id).to eq(id.id)
      expect(id.organization.id).to eq(organization.id)
      expect(id.user.id).to eq(user.id)
      expect(id.provider).to eq(oauth_provider)
      expect(id.uid).to eq(oauth_uid)
    end

    context "when an identity already exists" do
      let!(:identity) do
        user.identities.create!(
          organization: organization,
          provider: oauth_provider,
          uid: oauth_uid
        )
      end

      it "returns the same identity" do
        expect(subject.identify_user!(user).id).to eq(identity.id)
      end
    end

    context "when a matching identity already exists for another user" do
      let(:another_user) { create(:user, :confirmed, organization: organization) }

      before do
        another_user.identities.create!(
          organization: organization,
          provider: oauth_provider,
          uid: oauth_uid
        )
      end

      it "raises an IdentityBoundToOtherUserError" do
        expect do
          subject.identify_user!(user)
        end.to raise_error(
          Decidim::Tunnistamo::Authentication::IdentityBoundToOtherUserError
        )
      end
    end
  end

  describe "#authorize_user!" do
    let(:user) { create(:user, :confirmed, organization: organization) }
    let(:signature) do
      ::Decidim::OmniauthRegistrationForm.create_signature(
        oauth_provider,
        oauth_uid
      )
    end

    it "creates a new authorization for the user" do
      auth = subject.authorize_user!(user)

      expect(Decidim::Authorization.count).to eq(1)
      expect(Decidim::Authorization.last.id).to eq(auth.id)
      expect(auth.user.id).to eq(user.id)
      expect(auth.unique_id).to eq(signature)
      expect(auth.metadata).to include(
        "name" => "Marja Mirja Mainio",
        "given_name" => "Marja",
        "family_name" => "Mainio"
      )
    end

    context "when an authorization already exists" do
      let!(:authorization) do
        Decidim::Authorization.create!(
          name: "tunnistamo_idp",
          user: user,
          unique_id: signature
        )
      end

      it "returns the existing authorization and updates it" do
        auth = subject.authorize_user!(user)

        expect(auth.id).to eq(authorization.id)
        expect(auth.metadata).to include(
          "name" => "Marja Mirja Mainio",
          "given_name" => "Marja",
          "family_name" => "Mainio"
        )
      end
    end

    context "when a matching authorization already exists for another user" do
      let(:another_user) { create(:user, :confirmed, organization: organization) }

      before do
        Decidim::Authorization.create!(
          name: "tunnistamo_idp",
          user: another_user,
          unique_id: signature
        )
      end

      it "raises an IdentityBoundToOtherUserError" do
        expect do
          subject.authorize_user!(user)
        end.to raise_error(
          Decidim::Tunnistamo::Authentication::AuthorizationBoundToOtherUserError
        )
      end
    end
  end
end
