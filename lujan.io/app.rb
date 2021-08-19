require_relative 'router'
require_relative 'view'

class App
  def initialize()
    @router =
      Router.new do
        view = View.new('./views')

        static './public'

        redirect '/blm',
                 'https://docs.google.com/spreadsheets/d/1BSYzGR25aCFpNa2vZRmI8AeN5V5FTamYtLAYyVGvE3s/edit'

        get '/' do
          view.render :index
        end
      end
  end

  def call(env)
    request = Rack::Request.new(env)
    response = @router.route(request)
    return response.finish
  end
end

APP = App.new
