# frozen_string_literal: true

require 'sinatra'

require_relative 'redirects'
require_relative 'view'

class LujanIoApp < Sinatra::Base
  view = View.new('./views')

  set :public_folder, "#{__dir__}/public"

  get '/' do
    view.render :index, { template: :main }
  end

  Redirects::REDIRECTS.each do |path, target|
    get path do
      redirect to(target)
    end
  end
end
