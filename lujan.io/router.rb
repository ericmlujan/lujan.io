require 'mime/types'

class Router
  SUPPORTED_METHODS = %w[GET POST PUT DELETE]
  def initialize(&block)
    @static_dirs = []
    @redirects = []
    @routes = []

    instance_eval(&block) if block_given?
  end

  def route(request)
    @static_dirs.each do |dir|
      content = dir.fetch(request)
      if content
        response = Rack::Response.new
        response.content_type = MIME::Types.type_for(request.path).first.to_s
        response.write(content)
        return response
      end
    end

    @redirects.each do |redirect|
      if redirect.match(request)
        response = Rack::Response.new
        redirect.call(request, response)
        return response
      end
    end

    @routes.each do |route|
      if route.match(request)
        response = Rack::Response.new
        route.call(request, response)
        return response
      end
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

  class Redirect < Struct.new(:path, :redirect_uri)
    def match(request)
      return request.path == path
    end

    def call(request, response)
      redirect(redirect_uri, response)
    end

    def redirect(uri, response)
      response.status = 302
      response.set_header('Location', uri)
    end
  end

  class Route < Struct.new(:method, :path, :block)
    def match(request)
      return method_match?(request) && request.path == path
    end

    def call(request, response)
      content = block.call(request, response)
      response.content_type = 'text/html'
      response.write(content)
    end

    def method_match?(request)
      if !SUPPORTED_METHODS.include?(request.request_method) ||
           !SUPPORTED_METHODS.include?(method)
        return false
      end
      return request.request_method == method
    end
  end

  class StaticPath < Struct.new(:path)
    def fetch(request)
      return nil if request.request_method != 'GET'

      requested_file = File.join(path, request.path)
      if File.exist?(requested_file) && !File.directory?(requested_file)
        return File.read(requested_file)
      else
        return nil
      end
    end
  end
end
