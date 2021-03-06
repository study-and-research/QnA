require 'rails_helper'
require_relative 'shared_examples/publishing'

RSpec.describe AnswersController, type: :controller do
  let(:question) { create(:question) }
  let(:user) { create(:user) }
  let(:another_user) { create(:user) }
  before { sign_in(user) }

  describe 'POST #create' do
    let(:publish_url) { "/questions/#{question.id}/answers" }
    let(:make_request) { post :create, question_id: question.id, 
                              answer: attributes_for(:answer), format: :js }
    let(:post_invalid) { post :create, question_id: question.id, 
                              answer: attributes_for(:answer, body: nil), format: :js }

    it_behaves_like "publishing"

    context 'with valid info' do
      it 'saves answer in db and associates it with a proper question' do
        expect{ make_request }.to change(question.answers, :count).by(1)
      end

      it 'associates it with a current user' do
        expect{ make_request }.to change(user.answers, :count).by(1)
      end
    end

    context 'with invalid info' do
      it 'does not create answer in database' do
        expect{ post_invalid }.to_not change(Answer, :count)
      end

      it 'renders create' do
        post_invalid
        expect(response).to render_template :create
      end
    end

    context 'when user is not logged in' do
      before { sign_out user }

      it 'does not save answer in db' do
        expect{ make_request }.to_not change(Answer, :count)
      end

      it 'responds with 302' do
        make_request
        expect(response.status).to eq 302
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:answer) { question.answers.create(body: 'smth smth answer', user: user) }
    let(:delete_answer) { delete :destroy, question_id: question.id, id: answer.id, format: :js }
    
    context 'when current user is the author' do
      it 'deletes answer from db' do
        expect{ delete_answer }.to change(Answer, :count).by(-1)
      end
    end

    context 'when current user is not the author' do
      before { answer.update_attributes(user: another_user) }

      it 'does not delete answer' do
        expect{ delete_answer }.to_not change(Answer, :count)
      end
    end

    context 'when user is not logged in' do
      before do
        sign_out user
      end

      it 'does not delete answer' do
        expect{ delete_answer }.to_not change(Answer, :count)
      end

      it 'responds with 302' do
        delete_answer
        expect(response.status).to eq 302
      end
    end
  end

  describe 'PATCH #update' do
    let(:answer) { question.answers.create(body: 'smth smth answer', user: user) }
    let(:patch_request) { patch :update, question_id: question.id, id: answer.id,
                                  answer: { body: 'Edited answer' }, format: :js }

    context 'when logged in user is the author' do
      before do 
        patch_request
      end

      it 'assigns answer to a variable' do
        expect(assigns(:answer)).to eq answer
      end

      it 'changes answers body' do
        answer.reload
        expect(answer.body).to eq 'Edited answer'
      end
    end

    context 'when user is not author' do
      before do 
        answer.update_attributes(user: another_user) 
        patch_request
      end

      it 'does not update record in db' do
        answer.reload
        expect(answer.body).to_not eq 'Edited answer'
      end
    end

    context 'when user is not logged in' do
      before do 
        sign_out user
        patch_request
      end

      it 'does not update record in db' do
        answer.reload
        expect(answer.body).to_not eq 'Edited answer'
      end

      it 'responds with 302' do
        expect(response.status).to eq 302
      end
    end
  end

  describe 'PATCH #accept' do 
    let(:user) { create(:user, :author) }
    let(:other_user) { create(:user) }
    let(:question) { user.questions.last }
    let(:answers) { create_list(:answer, 5, question: question) }
    let(:answer) { answers[0] }

    before do
      sign_in(user)
    end

    context 'when user is the author of the question' do
      before do
        patch :accept, question_id: question.id, id: answer.id, format: :js
      end

      it 'assigns answer to a variable' do
        expect(assigns(:answer)).to eq answer
      end

      it 'assigns question to a variable' do
        expect(assigns(:question)).to eq question
      end 

      it 'sets accepted attr to true' do
        answer.reload
        expect(answer.accepted?).to be_truthy
      end

      it 'renders accept template' do
        expect(response).to render_template :accept
      end
    end

    context 'when user is not the author' do
      before do
        question.update_attributes(user: other_user)
        patch :accept, question_id: question.id, id: answer.id, format: :js
      end

      it 'does not change accepted status' do
        answer.reload
        expect(answer.accepted?).to be_falsey
      end
    end
  end

  describe 'PATCH #upvote' do
    let(:answer) { create(:answer, question_id: question.id) }
    let(:upvote) { patch :upvote, question_id: question.id, id: answer.id, format: :json }

    it 'increases the answers rating' do
      expect{upvote}.to change(answer, :rating).by 1
    end

    it 'renders vote template' do
      upvote
      expect(response).to render_template :vote
    end

    context 'when user is not logged in' do
      before do
        sign_out user
      end

      it 'does not increase rating' do
        expect{upvote}.to_not change(answer, :rating)
      end
    end

    context 'when user is author' do
      before do
        answer.update(user: user)
      end

      it 'does not increase rating' do
        expect{upvote}.to_not change(answer, :rating)
      end
    end
  end

  describe 'PATCH #downvote' do
    let(:answer) { create(:answer, question_id: question.id) }
    let(:downvote) { patch :downvote, question_id: question.id, id: answer.id, format: :json }

    it 'decreases the answers rating' do
      expect{downvote}.to change(answer, :rating).by -1
    end

    it 'renders vote template' do
      downvote
      expect(response).to render_template :vote
    end

    context 'when user is not logged in' do
      before do
        sign_out user
      end

      it 'does not increase rating' do
        expect{downvote}.to_not change(answer, :rating)
      end
    end

    context 'when user is author' do
      before do
        answer.update(user: user)
      end

      it 'does not increase rating' do
        expect{downvote}.to_not change(answer, :rating)
      end
    end
  end

  describe 'PATCH #recall_vote' do
    let(:answer) { create(:answer, question_id: question.id) }
    let(:recall_vote) { patch :recall_vote, question_id: question.id, id: answer.id, format: :json }

    before { answer.upvote_by(user) }

    it 'deletes users vote' do
      expect{ recall_vote }.to change(user.votes, :count).by -1
    end

    it 'deletes correct vote' do
      expect{ recall_vote }.to change(answer.votes, :count).by -1
    end

    context 'when user is not logged in' do
      before do
        sign_out user
      end

      it 'does not delete vote' do
        expect{ recall_vote }.to_not change(Vote, :count)
      end
    end

    context 'when user is author' do
      before do
        answer.update(user: user)
      end

      it 'does not delete vote' do
        expect{ recall_vote }.to_not change(Vote, :count)
      end
    end
  end
end
