require 'rails_helper'

RSpec.describe User, type: :model do
  it { should have_db_column(:name).of_type(:string) }
  it { should have_db_column(:email).of_type(:string) }
  it { should validate_presence_of(:email) }
  it { should validate_uniqueness_of(:email).case_insensitive }
  it { should validate_length_of(:email).is_at_most(150) }
  it { should allow_value('user@example.com', 'USER@foo.COM', 'A_US-ER@foo.bar.org',
                         'first.last@foo.jp', 'alice+bob@baz.cn').for(:email) }
  it { should_not allow_value('user@example,com', 'user_at_foo.org', 'user.name@example.',
                           'foo@bar_baz.com', 'foo@bar+baz.com', 'foo@bar..com').for(:email) }
  
  it 'saves email in all downcase' do
    user = create(:user, email: "EMilY@GmaiL.COM")
    user.reload
    expect(user.email).to eq "emily@gmail.com"
  end

  it { should have_many(:questions).dependent(:destroy) }
  it { should have_many(:answers).dependent(:destroy) }
  it { should have_many(:votes) }
  it { should have_many(:comments).dependent(:destroy) }
  it { should have_many(:authorizations).dependent(:destroy) }
  it { should have_and_belong_to_many(:questions_subscribed_to).dependent(:destroy) }

  describe '.find_for_oauth' do
    let!(:user) { create(:user) }
    let(:auth) { OmniAuth::AuthHash.new(provider:'facebook', uid: '123456') }

    context 'user already has authorization' do
      it 'returns user' do
        user.authorizations.create(provider: 'facebook', uid: '123456')
        expect(User.find_for_oauth(auth)).to eq user
      end
    end

    context 'user does not have authorization' do
      context 'user exists' do
        let(:auth) { OmniAuth::AuthHash.new(provider:'facebook', uid: '123456', info: { email: user.email }) }

        it 'does not create user' do
          expect{ User.find_for_oauth(auth) }.to_not change(User, :count)
        end

        it 'creates corresponding authorization' do
          expect{ User.find_for_oauth(auth) }.to change(user.authorizations, :count).by 1
        end

        it 'creates correct authorization' do
          user = User.find_for_oauth(auth)
          authorization = user.authorizations.last

          expect(authorization.provider).to eq auth.provider
          expect(authorization.uid).to eq auth.uid
        end

        it 'returns user' do
          expect(User.find_for_oauth(auth)).to eq user
        end
      end

      context 'user does not exist' do
        context 'when auth contains email' do
          let(:auth) { OmniAuth::AuthHash.new(provider:'facebook', uid: '123456', info: { email: 'new@user.com' }) }
        
          it 'creates user' do
            expect{ User.find_for_oauth(auth) }.to change(User, :count).by 1
          end

          it 'returns user' do
            expect(User.find_for_oauth(auth)).to be_a User
          end

          it 'fills in email' do
            user = User.find_for_oauth(auth)
            expect(user.email).to eq auth.info[:email]
          end

          it 'creates authorization for user' do
            user = User.find_for_oauth(auth)
            expect(user.authorizations).to_not be_empty
          end

          it 'assigns provider and uid' do
            user = User.find_for_oauth(auth)
            authorization = user.authorizations.last

            expect(authorization.provider).to eq auth.provider
            expect(authorization.uid).to eq auth.uid
          end
        end

        context 'when auth does not contain email' do
          let(:auth) { OmniAuth::AuthHash.new(provider:'twitter', uid: '123456', info: {}) }
        
          it 'returns nil' do
            expect(User.find_for_oauth(auth)).to eq nil
          end
        end
      end
    end
  end

  describe '.all_but' do
    let(:given_user) { create(:user) }
    let(:users) { create_list(:user, 3) }

    it 'returns all users index' do
      users.each do |user|
        expect(User.all_but(given_user).include? user).to be_truthy 
      end
    end

    it 'does not return given user' do
      expect(User.all_but(given_user).include? given_user).to be_falsey
    end
  end

  describe '.send_daily_digest' do
    let(:users) { create_list(:user, 2) }

    it 'should send daily digest to all users' do
      # Need to figure out why active job calls digest twice for each user. 
      # Sidekiq alone works as intended though.
      users.each { |user| expect(DailyMailer).to receive(:digest).with(user).and_call_original.exactly(2).times }
      User.send_daily_digest
    end
  end

  describe '#subscribed_to?' do
    let(:user) { create(:user) }
    let(:question) { create(:question) }

    it 'returns true if subscribed' do
      user.questions_subscribed_to << question
      expect(user.subscribed_to?(question)).to be_truthy
    end

    it 'returns false if not subscribed' do
      expect(user.subscribed_to?(question)).to be_falsey
    end
  end

  describe '#subscribe_to_new_answers' do
    let(:user) { create(:user) }
    let(:question) { create(:question) }

    before { user.subscribe_to_new_answers(question) }

    it 'subscribes user to question' do
      expect(user.questions_subscribed_to).to include(question)
    end
  end
end
