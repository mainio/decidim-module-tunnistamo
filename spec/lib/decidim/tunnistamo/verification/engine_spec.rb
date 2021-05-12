# frozen_string_literal: true

require "spec_helper"

describe Decidim::Tunnistamo::Verification::Engine do
  it "adds the correct routes" do
    expect(described_class.routes.recognize_path("/authorizations/new")).to eq(
      controller: "decidim/tunnistamo/verification/authorizations",
      action: "new"
    )
    expect(described_class.routes.recognize_path("/")).to eq(
      controller: "decidim/tunnistamo/verification/authorizations",
      action: "new"
    )
  end

  it "registers the verification workflow" do
    expect(Decidim::Verifications).to receive(
      :register_workflow
    ).with(:tunnistamo_idp) do |&block|
      workflow = double
      expect(workflow).to receive(:engine=).with(described_class)
      expect(workflow).to receive(:expires_in=).with(0.minutes)

      block.call(workflow)
    end

    run_initializer("decidim_tunnistamo.verification_workflow")
  end

  describe "#load_seed" do
    before { create(:organization) }

    it "adds :tunnistamo_idp to the organization's available authorizations" do
      described_class.load_seed

      org = Decidim::Organization.first
      expect(org.available_authorizations).to include("tunnistamo_idp")
    end
  end

  def run_initializer(initializer_name)
    config = described_class.initializers.find do |i|
      i.name == initializer_name
    end
    config.run
  end
end
