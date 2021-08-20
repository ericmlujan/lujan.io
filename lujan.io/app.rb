require_relative 'redirects'
require_relative 'router'
require_relative 'view'

class App
  def initialize()
    @router =
      Router.new do
        view = View.new('./views')

        static './public'

        get '/' do
          view.render :index
        end

        Redirects::Redirects.each { |path, target| redirect path, target }
      end
  end

  def call(env)
    request = Rack::Request.new(env)
    response = @router.route(request)
    return response.finish
  end
end

APP = App.new
