# frozen_string_literal: true

require_relative 'redirects'
require_relative 'router'
require_relative 'view'

class App
  def initialize
    @router =
      Router.new do
        Redirects::REDIRECTS.each { |path, target| redirect path, target }
        view = View.new('./views')

        static './public'

        get '/' do
          view.render :index, { template: :main }
        end
      end
  end

  def call(env)
    request = Rack::Request.new(env)
    response = @router.route(request)
    response.finish
  end
end

APP = App.new
