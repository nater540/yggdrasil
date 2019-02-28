# noinspection ALL
module Yggdrasil
  RSpec.describe FieldMap do
    it 'is available as described_class' do
      expect(described_class).to eq(FieldMap)
    end

    describe '#all_columns' do
      context 'it adds all model columns as inputs' do
        subject { described_class.new(User).all_columns }

        it 'has five inputs (`id`, `firstName`, `lastName`, `email`, `passwordDigest`)' do
          expect(subject.inputs.size).to eq(5)
        end
      end

      context 'it can exclude one column' do
        subject { described_class.new(User).all_columns(exclude: :id) }

        it 'has four inputs (`firstName`, `lastName`, `email`, `passwordDigest`)' do
          expect(subject.inputs.size).to eq(4)
        end
      end

      context 'it can exclude two columns' do
        subject { described_class.new(User).all_columns(exclude: %i[id password_digest]) }

        it 'has three inputs (`firstName`, `lastName`, `email`)' do
          expect(subject.inputs.size).to eq(3)
        end
      end

      context 'it accepts column options' do
        subject do
          described_class.new(User).all_columns(
            options: {
              password_digest: { name: 'password', required: true },
              first_name: { description: 'Pup Twister rules!' }
            }
          )
        end

        let(:password_digest) { subject.detect { |input| input[:attribute] == 'password_digest' } }
        let(:first_name)      { subject.detect { |input| input[:attribute] == 'first_name' } }

        it 'renamed the `password_digest` input to `password`' do
          expect(password_digest[:name]).to eq('password')
        end

        it 'requires the `password_digest` input' do
          expect(password_digest[:required]).to be_truthy
        end

        it 'set the `first_name` description to "Pup Twister rules!"' do
          expect(first_name[:description]).to eq('Pup Twister rules!')
        end
      end
    end

    describe '#exists?' do
      subject { described_class.new(User).input(:email) }

      it 'does have a `email` input' do
        expect(subject.exists?(:email)).to be_truthy
      end

      it 'does NOT have a `firstName` input' do
        expect(subject.exists?(:firstName)).to be_falsey
      end
    end

    describe '#has_many' do
      subject { described_class.new(User) }

      it 'creates an association to the `posts` model' do
        subject.has_many :posts do
          input :subject
        end
      end

      it 'raises an exception when the association does not exist' do
        expect { subject.belongs_to :shiba_inu_corgi_mix }.to raise_error(ArgumentError)
      end
    end
  end
end
