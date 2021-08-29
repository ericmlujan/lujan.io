require 'erb'

class View
  VIEW_EXTENSION = '.html.erb'
  TEMPLATE_DIR = 'templates'

  class TemplateError < RuntimeError
  end

  def initialize(view_path)
    @view_path = File.absolute_path(view_path.gsub(%r{^\/}, ''))
    @view_path << '/' if !@view_path.end_with?('/')

    @views = {}
    @templates = {}

    # Load views
    Dir
      .children(@view_path)
      .each do |child|
        if child.end_with? VIEW_EXTENSION
          name = File.basename(child, VIEW_EXTENSION)
          view(name)
        end
      end

    # Load templates
    template_path = File.join(@view_path, TEMPLATE_DIR)
    Dir
      .children(template_path)
      .each do |child|
        if child.end_with? VIEW_EXTENSION
          name = File.basename(child, VIEW_EXTENSION)
          template(name)
        end
      end
  end

  def render(name, options = {})
    if options.include? :template
      template_render(name, options[:template], options)
    else
      page_render(name, options)
    end
  end

  private

  def view(name)
    filepath = File.join(@view_path, name + VIEW_EXTENSION)
    File.open(filepath, 'r') { |file| @views[name.to_sym] = file.read }
  end

  def template(name)
    filepath = File.join(@view_path, TEMPLATE_DIR, name + VIEW_EXTENSION)
    File.open(filepath, 'r') { |file| @templates[name.to_sym] = file.read }
  end

  def page_render(name, options)
    renderer = ERB.new(@views[name])

    if options.include? :locals
      locals = options[:locals]
    else
      locals = {}
    end

    renderer.result_with_hash(locals)
  end

  def template_render(name, template, options)
    page_content = page_render(name, options)
    template_renderer = ERB.new(@templates[template])

    locals = { page_content: page_content }
    locals = locals.merge(options[:locals]) if options.include? :locals

    template_renderer.result_with_hash(locals)
  end
end
