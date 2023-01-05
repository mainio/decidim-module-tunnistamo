# frozen_string_literal: true

require "spec_helper"

describe Decidim::Tunnistamo::FormBuilder do
  let(:resource_base_class) do
    Class.new do
      def self.model_name
        ActiveModel::Name.new(self, nil, "dummy")
      end

      include ActiveModel::Model
      include Decidim::AttributeObject::Model

      attribute :name, String
    end
  end
  let(:resource_class) do
    Class.new(resource_base_class) do
      validates :name, presence: true
    end
  end
  let(:resource) { resource_class.new }
  let(:helper) { Class.new(ActionView::Base).new(ActionView::LookupContext.new(nil), {}, []) }
  let(:builder) { described_class.new(:resource, resource, helper, {}) }

  let(:parsed) { Nokogiri::HTML(output).css("body") }
  let(:parsed_label) { parsed.css("label")[0] }
  let(:parsed_required) { parsed_label.css("span")[0] }
  let(:parsed_group) { parsed.css(".input-group")[0] }

  describe "#group_text_field" do
    let(:output) do
      builder.group_text_field :name
    end

    it "generates the required field markup" do
      expect(parsed_label.text).to eq("Name*Required field")
      expect(parsed_required["title"]).to eq("Required field")
      expect(parsed_required.text).to eq("*Required field")
    end

    it "generates the Foundation abide error element" do
      expect(parsed.css(".form-error")).not_to be_empty
      expect(parsed.css(".form-error")[0].to_s).to eq('<span class="form-error" data-form-error-for="resource_name">There\'s an error in this field.</span>')
    end

    it "generates the correct input element" do
      expect(parsed_group.css("input").to_s).to eq('<input required="required" class="input-group-field" type="text" name="resource[name]" id="resource_name">')
    end

    context "when the field is not required" do
      let(:resource_class) { resource_base_class }

      it "does not generate the required field markup" do
        expect(parsed_label.text).to eq("Name")
      end

      it "does not generate the Foundation abide error element" do
        expect(parsed.css(".form-error")).to be_empty
      end

      it "does not mark the input as required" do
        expect(parsed_group.css("input")[0]["required"]).to be_nil
      end
    end

    context "when the resource has errors" do
      before do
        resource.errors.add(:name, "Please choose a different name")
        resource.errors.add(:name, "Your name cannot possibly be John")
      end

      it "marks the label as invalid" do
        expect(parsed_label["class"]).not_to be_nil
        expect(parsed_label["class"].split).to include("is-invalid-label")
      end

      it "marks the input as invalid" do
        input = parsed_group.css("input")[0]
        expect(input["class"]).to eq("input-group-field is-invalid-input")
      end

      it "adds the visible errors below the group field" do
        errors = parsed.css(".form-error")
        expect(errors.length).to eq(2)
        expect(errors[1].text).to eq("Please choose a different name, Your name cannot possibly be John")
        expect(errors[1]["class"]).to eq("form-error is-visible")
      end
    end

    context "with the prefix option" do
      let(:output) do
        builder.group_text_field :name, prefix: "PREFIX-"
      end

      it "generates a group text field with the prefix" do
        expect(parsed_group.to_s.strip).to eq(
          <<~HTML.strip
            <div class="input-group">
            <span class="input-group-label">PREFIX-</span><input required="required" class="input-group-field" type="text" name="resource[name]" id="resource_name">
            </div>
          HTML
        )
      end
    end

    context "with the suffix option" do
      let(:output) do
        builder.group_text_field :name, suffix: "SUFFIX-"
      end

      it "generates a group text field with the suffix" do
        expect(parsed_group.to_s.strip).to eq(
          <<~HTML.strip
            <div class="input-group">
            <input required="required" class="input-group-field" type="text" name="resource[name]" id="resource_name"><span class="input-group-label">SUFFIX-</span>
            </div>
          HTML
        )
      end
    end
  end
end
