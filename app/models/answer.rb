class Answer < ActiveRecord::Base
  belongs_to :question
  belongs_to :user
  validates :body, presence: true
  default_scope { order('accepted DESC') }
end
