class View
  def initialize(view_path)
    @view_path = File.absolute_path(view_path.gsub(/^\//, ""))

    if !@view_path.end_with?('/')
      @view_path << '/'
    end
  end

  def render(name)
    path = @view_path + name.to_s + ".html"

    body = ""
    File.open(path, "r") do |file|
      body = file.read
    end
    return body
  end
end
