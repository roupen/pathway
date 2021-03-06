require 'spec_helper'

module Pathway
  module Plugins
    describe 'SequelModels' do
      DB = Sequel.mock
      MyModel = Class.new(Sequel::Model(DB[:foo]))

      class MyOperation < Operation
        plugin :sequel_models

        context mailer: nil

        model MyModel, search_by: :email

        process do
          transaction do
            step :fetch_model
            after_commit do
              step :send_emails
            end
          end
        end

        def send_emails(my_model:,**)
          @mailer.send_emails(my_model) if @mailer
        end
      end

      let(:mailer) { double.tap { |d| allow(d).to receive(:send_emails) } }
      let(:operation) { MyOperation.new(mailer: mailer) }

      describe "DSL" do
        let(:result) { operation.call(params) }
        let(:params) { { email: 'asd@fgh.net' } }
        let(:model)  { double }

        describe "#transaction" do
          it "returns the result state provided by the inner transaction when successful" do
            allow(MyModel).to receive(:first).with(params).and_return(model)

            expect(result).to be_a_success
            expect(result.value).to eq(model)
          end

          it "returns the error state provided by the inner transaction when there's a failure" do
            allow(MyModel).to receive(:first).with(params).and_return(nil)

            expect(result).to be_a_failure
            expect(result.error.type).to eq(:not_found)
          end
        end

        describe "#after_commit" do
          it "calls after_commit block when transaction is successful" do
            allow(MyModel).to receive(:first).with(params).and_return(model)
            expect(mailer).to receive(:send_emails).with(model)

            expect(result).to be_a_success
          end

          it "does not call after_commit block when transaction fails" do
            allow(MyModel).to receive(:first).with(params).and_return(nil)

            expect(mailer).to_not receive(:send_emails)
            expect(result).to be_a_failure
          end
        end
      end

      describe '.model' do
        it "sets the 'result_key' using the model class name" do
          expect(operation.result_key).to eq(:my_model)
        end

        it "sets the 'model_class' using the first parameter" do
          expect(operation.model_class).to eq(MyModel)
        end

        it "sets the 'search_field' with the option value" do
          expect(operation.search_field).to eq(:email)
        end
      end

      describe '#db' do
        it 'returns the current db form the model class'  do
          expect(operation.db).to eq(DB)
        end
      end

      let(:key)    { "some@email.com" }
      let(:params) { { foo: 3, bar: 4} }

      describe '#find_model_with' do
        it "queries the db through the 'model_class'" do
          expect(MyModel).to receive(:first).with(email: key)

          operation.find_model_with(key)
        end
      end

      describe '#build_model_with' do
        it "creates a new model instance through the 'model_class'" do
          expect(MyModel).to receive(:new).with(params)

          operation.build_model_with(params)
        end
      end

      describe '#fetch_model' do
        let(:repository) { double }
        let(:object) { double }

        it "fetches an instance through 'model_class' and sets result key" do
          expect(repository).to receive(:first).with(pk: 'foo').and_return(object)
          expect(MyModel).to_not receive(:first)

          result = operation
                     .fetch_model({input: {myid: 'foo'}}, from: repository, key: :myid, column: :pk)
                     .value[:my_model]

          expect(result).to eq(object)
        end

        it "fetches an instance through 'model_class' into result key using default arguments if none specified" do
          expect(MyModel).to receive(:first).with(email: key).and_return(object)

          expect(operation.fetch_model(input: {email: key}).value[:my_model]).to eq(object)
        end

        it 'returns an error when no instance is found', :aggregate_failures do
          allow(MyModel).to receive(:first).with(email: key).and_return(nil)

          expect(operation.fetch_model(input: {email: key})).to be_an(Result::Failure)
          expect(operation.fetch_model(input: {email: key}).error).to be_an(Pathway::Error)
          expect(operation.fetch_model(input: {email: key}).error.type).to eq(:not_found)
        end
      end

      describe '#call' do
        class CtxOperation < MyOperation
          context my_model: nil
        end

        let(:operation)     { CtxOperation.new(ctx) }
        let(:result)        { operation.call(email: 'an@email.com') }
        let(:fetched_model) { MyModel.new }

        context "when the model is not present at the context" do
          let(:ctx) { {} }
          it "fetchs the model from the DB" do
            expect(MyModel).to receive(:first).with(email: 'an@email.com').and_return(fetched_model)

            expect(result.value).to be(fetched_model)
          end
        end

        context "when the model is already present in the context" do
          let(:existing_model) { MyModel.new }
          let(:ctx)            { { my_model: existing_model } }

          it "uses the model from the context and avoid querying the DB" do
            expect(MyModel).to_not receive(:first)

            expect(result.value).to be(existing_model)
          end

          context "but overwrite: option in step is true" do
            class RewOperation < CtxOperation
              context my_model: nil

              process do
                step :fetch_model, overwrite: true
              end
            end

            let(:operation) { RewOperation.new(ctx) }

            it "fetches the model from the DB anyway" do
              expect(MyModel).to receive(:first).with(email: 'an@email.com').and_return(fetched_model)

              expect(operation.my_model).to be(existing_model)
              expect(result.value).to be(fetched_model)
            end
          end
        end
      end
    end

  end
end
