# frozen_string_literal: true

require 'mime/types'

class Router
  SUPPORTED_METHODS = %w[GET POST PUT DELETE].freeze
  def initialize(&)
    @static_dirs = []
    @redirects = []
    @routes = []

    instance_eval(&) if block_given?
  end

  def route(request)
    @static_dirs.each do |dir|
      content = dir.fetch(request)
      next unless content

      response = Rack::Response.new
      response.content_type = MIME::Types.type_for(request.path).first.to_s
      response.write(content)
      return response
    end

    @redirects.each do |redirect|
      next unless redirect.match(request)

      response = Rack::Response.new
      redirect.call(request, response)
      return response
    end

    @routes.each do |route|
      next unless route.match(request)

      response = Rack::Response.new
      route.call(request, response)
      return response
    end
    Rack::Response.new('not found', 404)
  end

  def get(path, &block)
    @routes << Route.new('GET', path, block)
  end

  def static(path)
    @static_dirs << StaticPath.new(path)
  end

  def redirect(path, redirect_uri)
    @redirects << Redirect.new(path, redirect_uri)
  end

  Redirect = Struct.new(:path, :redirect_uri) do
    def match(request)
      request.path == path
    end

    def call(_request, response)
      redirect(redirect_uri, response)
    end

    def redirect(uri, response)
      response.status = 302
      response.set_header('Location', uri)
    end
  end

  Route = Struct.new(:http_method, :path, :block) do
    def match(request)
      method_match?(request) && request.path == path
    end

    def call(request, response)
      content = block.call(request, response)
      response.content_type = 'text/html'
      response.write(content)
    end

    def method_match?(request)
      if !SUPPORTED_METHODS.include?(request.request_method) ||
         !SUPPORTED_METHODS.include?(http_method)
        return false
      end

      request.request_method == http_method
    end
  end

  StaticPath = Struct.new(:path) do
    def fetch(request)
      return nil if request.request_method != 'GET'

      requested_file = File.join(path, request.path)
      return File.read(requested_file) if File.exist?(requested_file) && !File.directory?(requested_file)

      nil
    end
  end
end
