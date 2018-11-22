require 'rails_helper'

RSpec.describe '/v1' do
  describe 'GET /v1/users/?filter[auth_id]=' do
    it 'returns the details of a given user' do
      user = FactoryBot.create(:user)

      get "/v1/users?filter[auth_id]=#{CGI.escape(user.auth_id)}"

      expect(response).to be_successful
      expect(json['data'].size).to eql 1
      expect(json['data'][0]).to have_id(user.id)
      expect(json['data'][0])
        .to have_attribute(:name)
        .with_value('User Name')
      expect(json['data'][0])
        .to have_attribute(:multiple_suppliers?)
        .with_value(false)
    end

    it 'returns the details of given user with more than one supplier' do
      user = FactoryBot.create(:user)
      user.suppliers << FactoryBot.create_list(:supplier, 2)

      get "/v1/users?filter[auth_id]=#{CGI.escape(user.auth_id)}"

      expect(json['data'].size).to eql 1
      expect(response).to be_successful
      expect(json['data'][0])
        .to have_attribute(:multiple_suppliers?)
        .with_value(true)
    end
  end
  describe 'GET /v1/users' do
    it 'to return all users when no auth_id parameter is supplied' do
      FactoryBot.create(:user)
      FactoryBot.create(:user)

      get '/v1/users'
      expect(json['data'].size).to eql 2
      expect(response).to be_successful
    end
  end
end
