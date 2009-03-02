module AdminSidebarHelper

  def actions

    returning(String.new) do |html|

      html << <<-HTML
#{build_typus_list(default_actions, 'actions')}
#{build_typus_list(previous_and_next, 'go_to')}
      HTML

      %w( parent_module submodules ).each do |block|
        html << <<-HTML
#{build_typus_list(modules(block), block)}
        HTML
      end

    end

  end

  def default_actions

    items = []

    case params[:action]
    when 'index', 'edit', 'update'
      if @current_user.can_perform?(@resource[:class], 'create')
        items << (link_to t("Add entry"), :action => 'new')
      end
    end

    items += non_crud_actions

    case params[:action]
    when 'new', 'create', 'edit', 'update'
      items << (link_to t("Back to list"), :action => 'index')
    end

    return items

  end

  def non_crud_actions
    returning(Array.new) do |actions|
      @resource[:class].typus_actions_for(params[:action]).each do |action|
        if @current_user.can_perform?(@resource[:class], action)
          actions << (link_to action.humanize, params.merge(:action => action))
        end
      end
    end
  end

  def build_typus_list(items, header = nil, selector = nil)
    return "" if items.empty?
    returning(String.new) do |html|
      html << "<h2>#{I18n.t(header.humanize, :default => header.humanize)}</h2>" unless header.nil?
      next unless selector.nil?
      html << "<ul>\n"
      items.each do |item|
        html << "<li>#{item}</li>\n"
      end
      html << "</ul>\n"
    end
  end

  def modules(name)

    models = case name
             when 'parent_module': Typus.parent(@resource[:class_name], 'module')
             when 'submodules':    Typus.module(@resource[:class_name])
             end

    return [] if models.empty?

    returning(Array.new) do |items|
      models.each do |model|
        items << (link_to model.humanize, :controller => model.tableize)
      end
    end

  end

  def previous_and_next
    return [] unless %w( edit update ).include?(params[:action])
    returning(Array.new) do |items|
      items << (link_to t("Next"), :action => 'edit', :id => @next.id) if @next
      items << (link_to t("Previous"), :action => 'edit', :id => @previous.id) if @previous
    end
  end

  def search

    typus_search = @resource[:class].typus_defaults_for(:search)
    return if typus_search.empty?

    to_sentence_options = case Rails.version
                          when '2.3.1'
                            { :words_connector => ', ', :last_word_connector => ' & ' }
                          else
                            { :skip_last_comma => true, :connector => '&' }
                          end

    search_by = typus_search.collect { |x| t(x) }.to_sentence(to_sentence_options).titleize.downcase

    search_params = params.dup
    %w( action controller search page ).each { |p| search_params.delete(p) }

    hidden_params = search_params.map { |key, value| hidden_field_tag(key, value) }

    returning(String.new) do |html|
      html << <<-HTML
<h2>#{t("Search")}</h2>
<form action="" method="get">
<p><input id="search" name="search" type="text" value="#{params[:search]}"/></p>
#{hidden_params.join("\n")}
</form>
<p class="tip">#{t("Search by")} #{search_by}.</p>
      HTML
    end

  end

  def filters

    typus_filters = @resource[:class].typus_filters
    return if typus_filters.empty?

    current_request = request.env['QUERY_STRING'] || []

    returning(String.new) do |html|
      typus_filters.each do |key, value|
        case value
        when :boolean:      html << boolean_filter(current_request, key)
        when :string:       html << string_filter(current_request, key)
        when :datetime:     html << datetime_filter(current_request, key)
        when :belongs_to:   html << relationship_filter(current_request, key)
        when :has_and_belongs_to_many:
          html << relationship_filter(current_request, key, true)
        else
          html << "<p>Unknown</p>"
        end
      end
    end

  end

  def relationship_filter(request, filter, habtm = false)

    model = (habtm) ? filter.classify.constantize : filter.capitalize.camelize.constantize
    related_fk = (habtm) ? filter : @resource[:class].reflect_on_association(filter.to_sym).primary_key_name

    params_without_filter = params.dup
    %w( controller action page ).each { |p| params_without_filter.delete(p) }
    params_without_filter.delete(related_fk)

    items = []

    returning(String.new) do |html|
      related_items = model.find(:all, :order => model.typus_order_by)
      if related_items.size > model.typus_options_for(:sidebar_selector)
        related_items.each do |item|
          switch = request.include?("#{related_fk}=#{item.id}") ? 'selected' : ''
          items << <<-HTML
<option #{switch} value="#{url_for params.merge(related_fk => item.id, :page => nil)}">#{item.typus_name}</option>
          HTML
        end
        model_pluralized = model.name.downcase.pluralize
        form = <<-HTML
<!-- Embedded JS -->
<script>
function surfto_#{model_pluralized}(form) {
  var myindex = form.#{model_pluralized}.selectedIndex
  if (form.#{model_pluralized}.options[myindex].value != "0") {
    top.location.href = form.#{model_pluralized}.options[myindex].value;
  }
}
</script>
<!-- /Embedded JS -->
<p><form class="form" action="#">
  <select name="#{model_pluralized}" onChange="surfto_#{model_pluralized}(this.form)">
    <option value="#{url_for params_without_filter}">#{t("filter by")} #{t(model.name.titleize)}</option>
    #{items.join("\n")}
  </select>
</form></p>
        HTML
      else
        related_items.each do |item|
          switch = request.include?("#{related_fk}=#{item.id}") ? 'on' : 'off'
          items << (link_to item.typus_name, { :params => params.merge(related_fk => item.id, :page => nil) }, :class => switch)
        end
      end

      if form
        html << build_typus_list(items, filter, true)
        html << form
      else
        html << build_typus_list(items, filter)
      end

    end

  end

  def datetime_filter(request, filter)
    items = []
    %w( today past_7_days this_month this_year ).each do |timeline|
      switch = request.include?("#{filter}=#{timeline}") ? 'on' : 'off'
      items << (link_to timeline.titleize, { :params => params.merge(filter => timeline, :page => nil) }, :class => switch)
    end
    build_typus_list(items, filter)
  end

  def boolean_filter(request, filter)
    items = []
    @resource[:class].typus_boolean(filter).each do |key, value|
      switch = request.include?("#{filter}=#{key}") ? 'on' : 'off'
      items << (link_to t(value), { :params => params.merge(filter => key, :page => nil) }, :class => switch)
    end
    build_typus_list(items, filter)
  end

  def string_filter(request, filter)
    values = @resource[:class].send(filter)
    next if values.empty?
    items = []
    values.each do |item|
      switch = request.include?("#{filter}=#{item}") ? 'on' : 'off'
      items << (link_to item.capitalize, { :params => params.merge(filter => item, :page => nil) }, :class => switch)
    end
    build_typus_list(items, filter)
  end

end