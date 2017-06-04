require 'spec_helper'

module Pathway
  describe Operation do
    SimpleModel = Struct.new(:name, :email, :role, :profile)

    SimpleForm = Dry::Validation.Form(Pathway::Form) do
      required(:age).filled(:int?)
    end

    class SimpleOperation < Operation
      scope :user, :repository

      authorization { user.role == :root }

      form do
        required(:name).filled(:str?)
        optional(:email).maybe(:str?)
      end

      def call(params)
        validate_with(params)
          .then { |params|  fetch_profile(params) }
          .tee  { |profile| authorize_with(nil) }
          .then { |profile| update_model(params, profile) }
      end

      private

      def fetch_profile(params)
        wrap_if_present(repository.fetch(params))
      end

      def update_model(params, profile)
        SimpleModel.new(*params.values, user.role, profile)
      end
    end

    describe ".form_class" do
      subject(:operation_class) { Class.new(Operation) }

      context "when no form's been setup" do
        it "returns a default empty form" do
          expect(operation_class.form_class).to eq(Pathway::Form)
        end
      end

      context "when a form's been set" do
        it "returns the form" do
          operation_class.form_class = SimpleForm
          expect(operation_class.form_class).to eq(SimpleForm)
        end
      end
    end

    describe ".build_form" do
      subject(:operation_class) do
        Class.new(Operation) do
          form do
            configure do
              option :quz
              define_method(:quz?) { |val| val == quz }
            end

            required(:qux).value(:quz?)
          end
        end
      end

      let(:form) { operation_class.build_form(quz: "XXX") }

      it "uses passed the option from the context to the form" do
        expect(form.call(qux: "XXX")).to be_a_success
      end
    end

    describe ".form" do
      context "when called with a form" do
        subject(:operation_class) { Class.new(Operation) { form SimpleForm } }

        it "uses the passed form's class" do
          expect(operation_class.form_class).to eq(SimpleForm.class)
        end

        context "and a block" do
          subject(:operation_class) do
            Class.new(Operation) do
              form(SimpleForm) { required(:gender).filled }
            end
          end

          it "extend from the form's class" do
            expect(operation_class.form_class).to be < SimpleForm.class
          end

          it "extends the form rules with the block's rules" do
            expect(operation_class.form_class.rules.map(&:name))
              .to include(:age, :gender)
          end
        end
      end

      context "when called with a form class" do
        subject(:operation_class) { Class.new(Operation) { form SimpleForm.class } }

        it "uses the passed class as is" do
          expect(operation_class.form_class).to eq(SimpleForm.class)
        end
      end

      context "when called with a block" do
        subject(:operation_class) do
          Class.new(Operation) do
            form { required(:gender).filled }
          end
        end

        it "extends from the operations superclass form" do
          expect(operation_class.form_class).to be < Pathway::Form
        end

        it "uses the rules defined at the passed block" do
          expect(operation_class.form_class.rules.map(&:name))
            .to include(:gender)
        end
      end
    end

    describe ".authorization" do
      subject(:operation_class) do
        Class.new(Operation) do
          scope :role
          authorization { role == :admin }
        end
      end

      it "defines an 'authorized?' method using provided block", :aggregate_failures do
        expect(operation_class.new(role: :admin)).to be_authorized
        expect(operation_class.new(role: :clerk)).not_to be_authorized
      end
    end

    describe ".scope" do
      subject(:operation_class) do
        Class.new(Operation) { scope :foo, :bar }
      end

      it "includes an Scope module defining the scope dependencies" do
        operation = operation_class.new(foo: "XXX", bar: "YYY")

        expect(operation.foo).to eq("XXX")
        expect(operation.bar).to eq("YYY")
      end
    end

    describe ".call" do
      let(:ctx)    { { user: double("User", role: :root), repository: double("Repo") } }
      let(:params) { { name: "Paul Smith", email: "psmith@email.com" } }
      before { allow(ctx[:repository]).to receive(:fetch).and_return(double) }

      context "when no block is given" do
        let(:result) { SimpleOperation.(ctx, params) }

        it "instances an operation an executes 'call'", :aggregate_failures do
          expect(result).to be_kind_of(Pathway::Result)
          expect(result.value).to be_kind_of(SimpleModel)
          expect(result.value.to_h).to match(**params, role: ctx[:user].role, profile: anything)
        end
      end

      context "when a block is given" do
        let(:responder) { class_double("Pathway::Responder").as_stubbed_const }

        it "expected to invoke responder with the operation result and passed block" do
          expect(responder).to receive(:respond) do |result, &block|
            expect(result).to be_a(Pathway::Result)
            expect(block).to be_a(Proc)
          end

          SimpleOperation.(ctx, params) do
            success { |value| value.name }
            failure { |error| "Invalid: " + error.join(", ") }
          end

        end
      end
    end

    describe "#call" do
      subject(:operation) { SimpleOperation.new(ctx) }

      let(:ctx)        { { user: double("User", role: role), repository: repository } }
      let(:role)       { :root }
      let(:params)     { { name: "Paul Smith", email: "psmith@email.com" } }
      let(:result)     { operation.call(params) }
      let(:repository) { double.tap { |repo| allow(repo).to receive(:fetch).and_return(double) } }

      context "when calling with valid params" do
        it "returns a successful result", :aggregate_failures do
          expect(result).to be_a_success
          expect(result.value).to_not be_nil
        end
      end

      context "when finding model fails" do
        let(:repository) { double.tap { |repo| allow(repo).to receive(:fetch).and_return(nil) } }
        it "returns a a failed result", :aggregate_failures do
          expect(result).to be_a_failure
          expect(result.error.type).to eq(:not_found)
        end
      end

      context "when calling with invalid params" do
        let(:params) { { email: "psmith@email.com" } }
        it "returns a failed result", :aggregate_failures do
          expect(result).to be_a_failure
          expect(result.error.type).to eq(:validation)
          expect(result.error.details).to eq(name: ['is missing'])
        end
      end

      context "when calling with without proper authorization" do
        let(:role) { :user }
        it "returns a failed result", :aggregate_failures do
          expect(result).to be_a_failure
          expect(result.error.type).to eq(:forbidden)
        end
      end
    end
  end
end