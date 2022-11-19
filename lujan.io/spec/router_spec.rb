# frozen_string_literal: true

require 'rack'

require_relative '../router'

def make_mock_request(uri)
  env = Rack::MockRequest.env_for(uri)
  Rack::Request.new(env)
end

RSpec.describe Router, '#route' do
  context 'no routes loaded' do
    it 'returns a 404 error' do
      router = Router.new
      request = make_mock_request('/')
      response = router.route(request)

      expect(response.status).to eq(404)
      expect(response.body).to eq(['not found'])
    end
  end

  context 'GET / is defined' do
    it 'returns an ok status' do
      body_text = 'i am root'

      router =
        Router.new do
          get '/' do
            body_text
          end
        end

      request = make_mock_request('/')
      response = router.route(request)

      expect(response.status).to eq(200)
      expect(response.body).to eq([body_text])
    end
  end
end
