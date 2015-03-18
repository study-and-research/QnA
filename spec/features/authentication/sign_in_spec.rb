require 'rails_helper'

feature 'Sign in process', %q{
  In order to be able to ask questions
  As a user
  I must be able to sign in
} do

  scenario 'Registered user tries to sign in' do
    user = create(:user)

    visit root_path
    click_on 'Sign In'
    fill_in 'Email', with: user.email
    fill_in 'Password', with: user.password
    click_button 'Log in'

    expect(current_path).to eq root_path
    expect(page).to have_content 'Signed in successfully.'  
  end

  scenario 'Non-registered user tries to sign in' do
    user = build(:user)

    visit root_path
    click_on 'Sign In'
    fill_in 'Email', with: user.email
    fill_in 'Password', with: user.password
    click_button 'Log in'

    expect(current_path).to eq new_user_session_path
    expect(page).to have_content 'Invalid email or password.'
  end
end