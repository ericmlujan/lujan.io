class View
  def initialize(view_path)
    @view_path = File.absolute_path(view_path.gsub(%r{^\/}, ''))

    @view_path << '/' if !@view_path.end_with?('/')
  end

  def render(name)
    path = @view_path + name.to_s + '.html'

    body = ''
    File.open(path, 'r') { |file| body = file.read }
    return body
  end
end
