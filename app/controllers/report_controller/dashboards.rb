module ReportController::Dashboards
  extend ActiveSupport::Concern
  include DashboardHelper

  def db_seq_edit
    assert_privileges("db_seq_edit")
    case params[:button]
    when "cancel"
      @edit = session[:edit] = nil # clean out the saved info
      add_flash(_("Edit of Dashboard Sequence was cancelled by the user"))
      replace_right_cell
    when "save"
      return unless load_edit("db_edit__seq", "replace_cell__explorer")
      err = false
      dashboard_order = []
      @edit[:new][:dashboard_order].each do |n|
        dashboard_order.push(MiqWidgetSet.where_unique_on(n).first.id)
      end
      g = MiqGroup.find(@sb[:nodes][2])
      g.settings ||= {}
      g.settings[:dashboard_order] ||= {}
      g.settings[:dashboard_order] = dashboard_order
      if g.save
        AuditEvent.success(build_saved_audit(g, @edit))
      else
        g.errors.each do |field, msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        err = true
      end
      if !err
        add_flash(_("Dashboard Sequence was saved"))
        @edit = session[:edit] = nil # clean out the saved info
        replace_right_cell(:replace_trees => [:db])
      else
        @in_a_form = true
        @changed = true
        javascript_flash
      end
    when "reset", nil # Reset or first time in
      db_seq_edit_screen
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      session[:changed] = @changed = false
      replace_right_cell
    end
  end

  def db_new
    assert_privileges("db_new")
    db_edit
  end

  def db_copy
    assert_privileges("db_copy")

    case params[:button]
    when "cancel"
      db_copy_cancel
    when "save"
      dashboard = find_record_with_rbac(MiqWidgetSet, params[:dashboard_id])
      begin
        MiqWidgetSet.copy_dashboard(dashboard, params[:name], params[:description], params[:group_id])
        render :json => { :name => dashboard.name }, :status => :ok
      rescue => bang
        render :json => { :error => { :message => _("Error during 'Validate': %{message}") % {:message => bang.to_s} } }, :status => :bad_request
      end
    else
      checked_id = find_checked_items.first || params[:id]
      @record = find_record_with_rbac(MiqWidgetSet, checked_id)
      @tabactive = false
      @in_a_form = true
      @edit = {}
      @edit[:db_id] = @record.id
      session[:changed] = false
      @right_cell_text = _("Copy of \"%{dashboard}\" Dashboard") % {:dashboard => @record.name}
      replace_right_cell(:action => "copy_dashboard")
    end
  end

  def db_copy_cancel
    add_flash(_("Copy of Dashboard was cancelled by the user"))
    get_node_info
    @edit = session[:edit] = @sb[:action] = nil # clean out the saved info
    @dashboard = nil
    replace_right_cell
  end

  def dashboard_get
    assert_privileges("db_copy")

    if params[:name]
      dashboard = MiqWidgetSet.where(:name => params[:name]).to_a
      render :json => {:length => dashboard.length}
    else
      dashboard = MiqWidgetSet.select(:name, :description, :owner_id).find_by(:id => params[:id])
      render :json => {
        :name        => dashboard.name,
        :description => dashboard.description,
        :owner_id    => dashboard.owner_id.to_s
      }
    end
  end

  def dashboard_render
    assert_privileges("db_copy")

    get_node_info
    @edit = session[:edit] = @sb[:action] = nil # clean out the saved info
    @dashboard = nil
    add_flash(_("Copy of \"%{original_name}\" Dashboard: \"%{name}\" was succesfully saved into \"%{group}\" Group.") % {:original_name => params[:original_name], :name => params[:name], :group => params[:group]})
    replace_right_cell(:replace_trees => [:db])
  end

  def db_edit
    assert_privileges("db_edit")

    case params[:button]
    when "cancel"
      @dashboard = MiqWidgetSet.find_by(:id => session[:edit][:db_id]) if session[:edit] && session[:edit][:db_id]
      if !@dashboard || @dashboard.id.blank?
        add_flash(_("Add of new Dashboard was cancelled by the user"))
      else
        add_flash(_("Edit of Dashboard \"%{name}\" was cancelled by the user") % {:name => get_record_display_name(@dashboard)})
      end
      get_node_info
      @edit = session[:edit] = nil # clean out the saved info
      @dashboard = nil
      replace_right_cell
    when "add", "save"
      assert_privileges("db_#{@edit[:db_id] ? "edit" : "new"}")
      @dashboard = @edit[:db_id] ? MiqWidgetSet.find(@edit[:db_id]) : MiqWidgetSet.new # get the current record
      db_fields_validation
      db_set_record_vars
      if params[:button] == "add"
        g = MiqGroup.find(@sb[:nodes][2])
        @dashboard.owner = g
      end
      if @flash_array.nil? && @dashboard.save
        db_save_members
        AuditEvent.success(build_saved_audit(@dashboard, @edit))
        add_flash(_("Dashboard \"%{name}\" was saved") % {:name => get_record_display_name(@dashboard)})
        if params[:button] == "add"
          widgetset = MiqWidgetSet.where_unique_on(@edit[:new][:name]).first
          settings = g.settings ? g.settings : {}
          settings[:dashboard_order] = settings[:dashboard_order] ? settings[:dashboard_order] : []
          settings[:dashboard_order].push(widgetset.id) unless settings[:dashboard_order].include?(widgetset.id)
          g.save
        end
        params[:id] = @dashboard.id.to_s # reset id in params for show
        @edit = session[:edit] = nil # clean out the saved info
        replace_right_cell(:replace_trees => [:db])
      else
        @dashboard.errors.each do |field, msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        @changed = session[:changed] = (@edit[:new] != @edit[:current])
        javascript_flash
      end
    else
      add_flash(_("All changes have been reset"), :warning) if params[:button] == "reset"
      @dashboard = params[:id] && params[:id] != "new" ? find_record_with_rbac(MiqWidgetSet, params[:id]) : MiqWidgetSet.new
      db_set_form_vars
      session[:changed] = false
      @in_a_form = true
      replace_right_cell
    end
  end

  # Delete all selected or single displayed action(s)
  def db_delete
    assert_privileges("db_delete")
    db = MiqWidgetSet.find(params[:id]) # temp var to determine the parent node of deleted items
    process_elements(db, MiqWidgetSet, "destroy")
    g = MiqGroup.find(@sb[:nodes][2].split('_').first)
    # delete dashboard id from group settings and save
    db_order = g.settings && g.settings[:dashboard_order] ? g.settings[:dashboard_order] : nil
    db_order&.delete(db.id)
    g.save
    nodes = x_node.split('-')
    self.x_node = "#{nodes[0]}-#{nodes[1]}-#{nodes[2].split('_').first}"
    replace_right_cell(:replace_trees => [:db])
  end

  def db_form_field_changed
    assert_privileges(session.fetch_path(:edit, :db_id) ? "db_edit" : "db_new")

    return unless load_edit("db_edit__#{params[:id]}", "replace_cell__explorer")
    db_get_form_vars
    render :update do |page|
      page << javascript_prologue
      changed = (@edit[:new] != @edit[:current])
      if params[:widget]
        page.replace("form_div", :partial => "db_form")
        # url to be used in url in miqDropComplete method
        page << "ManageIQ.widget.dashboardUrl = 'report/db_widget_dd_done'"
        page << "miqInitDashboardCols();"
      end
      if %w[up down].include?(params[:button])
        page.replace("flash_msg_div", :partial => "layouts/flash_msg") unless @refresh_div && @refresh_div != "column_lists"
        page << "miqScrollTop();" if @flash_array.present?
        page.replace(@refresh_div, :partial => @refresh_partial, :locals => {:action => "db_seq_edit"}) if @refresh_div
      end
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  # A widget has been dropped
  def db_widget_dd_done
    assert_privileges("db_delete")

    set_edit_new_cols
    db_available_widgets_options
    render :update do |page|
      page << javascript_prologue
      changed = (@edit[:new] != @edit[:current])
      if params[:widget]
        page.replace("form_div", :partial => "db_form")
        # url to be used in url in miqDropComplete method
        page << "ManageIQ.widget.dashboardUrl = 'report/db_widget_dd_done'"
        page << "miqInitDashboardCols();"
      end
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  def db_widget_remove
    assert_privileges("db_delete")

    return unless load_edit("db_edit__#{params[:id]}", "replace_cell__explorer")
    @dashboard = @edit[:db_id] ? MiqWidgetSet.find(@edit[:db_id]) : MiqWidgetSet.new
    w = params[:widget].to_i
    @edit[:new][:col1].delete(w) if @edit[:new][:col1].include?(w)
    @edit[:new][:col2].delete(w) if @edit[:new][:col2].include?(w)
    db_available_widgets_options
    @in_a_form = true
    render :update do |page|
      page << javascript_prologue
      changed = (@edit[:new] != @edit[:current])
      if params[:widget]
        page.replace("form_div", :partial => "db_form")
        # url to be used in url in miqDropComplete method
        page << "ManageIQ.widget.dashboardUrl = 'report/db_widget_dd_done'"
        page << "miqInitDashboardCols();"
      end
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  private

  def set_edit_new_cols
    if params[:col1] || params[:col2]
      if params[:col1] && params[:col1] != [""]
        @edit[:new][:col1] = params[:col1].collect { |w| w.split("_").last.to_i }
        @edit[:new][:col2].delete_if { |w| @edit[:new][:col1].include?(w) }
      elsif params[:col2] && params[:col2] != [""]
        @edit[:new][:col2] = params[:col2].collect { |w| w.split("_").last.to_i }
        @edit[:new][:col1].delete_if { |w| @edit[:new][:col2].include?(w) }
      end
    end
  end

  def db_get_node_info
    model, rec_id, _ = TreeBuilder.extract_node_model_and_id(x_node)
    @sb[:nodes] = x_node.split('-')
    if @sb[:nodes].length == 1
      @default_ws = MiqWidgetSet.where_unique_on("default").where(:read_only => true).first
      @right_cell_text = _("All Dashboards")
      @right_cell_div  = "db_list"
      @db_nodes = {}
      @db_nodes_order = [@default_ws.name, "All Groups"]

      @db_nodes[@default_ws.name] = {}
      @db_nodes[@default_ws.name][:id] = "xx-#{@default_ws.id}"
      @db_nodes[@default_ws.name][:text] = "#{@default_ws.description} (#{@default_ws.name})"
      @db_nodes[@default_ws.name][:title] = "#{@default_ws.description} (#{@default_ws.name})"
      @db_nodes[@default_ws.name][:glyph] = "fa fa-dashboard"

      @db_nodes["All Groups"] = {}
      @db_nodes["All Groups"][:id] = "xx-g"
      @db_nodes["All Groups"][:glyph] = "pficon pficon-folder-close"
      @db_nodes["All Groups"][:title] = "All Groups"
      @db_nodes["All Groups"][:text] = "All Groups"
    elsif @sb[:nodes].length == 2 && @sb[:nodes].last == "g"
      # All groups node is selected
      @miq_groups = Rbac.filtered(MiqGroup.non_tenant_groups_in_my_region)
      @right_cell_div  = "db_list"
      @right_cell_text = _("All EVM Groups")
    elsif @sb[:nodes].length == 3 && @sb[:nodes][1] == "g_g"
      g = MiqGroup.find(@sb[:nodes].last)
      @right_cell_text = _("Dashboards for \"%{name}\"") % {:name => g.description}
      @right_cell_div  = "db_list"
      widgetsets = MiqWidgetSet.where(:owner_type => "MiqGroup", :owner_id => g.id)
      @widgetsets = []
      if g.settings && g.settings[:dashboard_order]
        g.settings[:dashboard_order].each do |ws_id|
          widgetsets.each do |ws|
            @widgetsets.push(ws) if ws_id == ws.id && !@widgetsets.include?(ws)
          end
        end
      else
        widgetsets.sort_by(&:name).each do |ws|
          @widgetsets.push(ws)
        end
      end
    elsif model == "MiqWidgetSet"
      # default dashboard nodes is selected or one under a specific group is selected
      # g = MiqGroup.find(@sb[:nodes][2])
      @record = @dashboard = MiqWidgetSet.find(rec_id)
      @right_cell_text = _("Dashboard \"%{name}\"") % {:name => "#{@dashboard.description} (#{@dashboard.name})"}
      @right_cell_div  = "db_list"
      @sb[:new] = {}
      @sb[:new][:name] = @dashboard.name
      @sb[:new][:description] = @dashboard.description
      @sb[:new][:locked] = @dashboard[:set_data] && @dashboard[:set_data][:locked] ? @dashboard[:set_data][:locked] : true
      @sb[:new][:reset_upon_login] = @dashboard[:set_data] && @dashboard[:set_data][:reset_upon_login] ? @dashboard[:set_data][:reset_upon_login] : true
      @sb[:new][:col1], @sb[:new][:col2] = column_widgets(@dashboard[:set_data])
    end
  end

  def db_get_form_vars
    @in_a_form = true
    @dashboard = @edit[:db_id] ? MiqWidgetSet.find(@edit[:db_id]) : MiqWidgetSet.new
    if %w[up down].include?(params[:button])
      db_move_cols_up if params[:button] == "up"
      db_move_cols_down if params[:button] == "down"
    else
      copy_params_if_present(@edit[:new], params, %i[name description])

      if params[:locked]
        @edit[:new][:locked] = params[:locked].to_i == 1
      end

      @edit[:new][:reset_upon_login] = params[:reset_upon_login].to_i == 1 if params[:reset_upon_login].present?

      if params[:widget] # Make sure we got a widget in
        w = params[:widget].to_i
        if @edit[:new][:col2].length < @edit[:new][:col1].length
          @edit[:new][:col2].insert(0, w)
        else
          @edit[:new][:col1].insert(0, w)
        end
        db_available_widgets_options
      end
      set_edit_new_cols
    end
  end

  def db_set_record_vars
    @dashboard.name = @edit[:new][:name]
    @dashboard.description = @edit[:new][:description]
    @dashboard.updated_on = Time.now.utc
    @dashboard.set_data = {} unless @dashboard.set_data
    @dashboard.set_data[:col1] = [] if !@dashboard.set_data[:col1] && !@edit[:new][:col1].empty?
    @dashboard.set_data[:col2] = [] if !@dashboard.set_data[:col2] && !@edit[:new][:col2].empty?
    @dashboard.set_data[:col1] = @edit[:new][:col1]
    @dashboard.set_data[:col2] = @edit[:new][:col2]
    @dashboard.set_data[:locked] = @edit[:new][:locked]
    @dashboard.set_data[:reset_upon_login] = @edit[:new][:reset_upon_login]
  end

  def db_save_members
    widget_ids = %i[col1 col2].collect { |key| @dashboard.set_data[key] }.flatten
    widgets = Array(MiqWidget.where(:id => widget_ids))

    @dashboard.replace_children(widgets)
    @dashboard.members.each { |w| w.create_initial_content_for_user(session[:userid]) } # Generate content if not there
  end

  def db_fields_validation
    if @edit[:new][:name] && @edit[:new][:name].index('|')
      add_flash(_("Name cannot contain \"|\""), :error)
      return
    end
    # no need to check this for default dashboard, it doesn't belong to any group
    if @sb[:nodes][1] == "g_g"
      ws = MiqWidgetSet.where(:owner_id => @sb[:nodes][2])
      # make sure description is unique within group
      ws.each do |w|
        if w.description == @edit[:new][:description] && (@edit[:db_id] && w.id != @edit[:db_id])
          add_flash(_("Tab Title must be unique for this group"), :error)
          break
        end
      end
    end
    if @edit[:new][:col1].empty? && @edit[:new][:col2].empty?
      add_flash(_("One widget must be selected"), :error)
      return
    end
  end

  def db_set_form_vars
    @timezone_abbr = get_timezone_abbr
    @edit = {}
    @edit[:db_id] = @dashboard.id
    @edit[:read_only] = !!@dashboard.read_only

    # Remember how this edit started
    @edit[:type] = params[:id] ? "db_edit" : "db_new"
    @edit[:key]  = params[:id] ? "db_edit__#{@dashboard.id}" : "db_edit__new"
    @edit[:new] = {}
    @edit[:new][:name] = @dashboard.name
    @edit[:new][:description] = @dashboard.description
    @edit[:new][:locked] = @dashboard[:set_data] && @dashboard[:set_data][:locked] ? @dashboard[:set_data][:locked] : false
    @edit[:new][:reset_upon_login] = @dashboard[:set_data] && @dashboard[:set_data][:reset_upon_login] ? @dashboard[:set_data][:reset_upon_login] : false
    @edit[:new][:col1], @edit[:new][:col2] = column_widgets(@dashboard[:set_data])
    db_available_widgets_options
    @edit[:current] = copy_hash(@edit[:new])
  end

  def db_seq_edit_screen
    assert_privileges("db_seq_edit")

    @in_a_form = true
    @edit = {}
    @edit[:new] = {}
    @edit[:current] = {}
    @edit[:new][:dashboard_order] = []
    g = MiqGroup.find(@sb[:nodes][2])
    @sb[:group_desc] = g.description # saving for cell header
    if g.settings && g.settings[:dashboard_order]
      dbs = g.settings[:dashboard_order]
      dbs.each do |db|
        ws = MiqWidgetSet.find(db)
        @edit[:new][:dashboard_order].push(ws.name)
      end
    else
      dbs = MiqWidgetSet.where(:owner_type => "MiqGroup", :owner_id => g.id)
      dbs.sort_by(&:name).each do |ws|
        @edit[:new][:dashboard_order].push(ws.name)
      end
    end

    @edit[:key] = "db_edit__seq"
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  def db_available_widgets_options
    # Build the available widgets for the pulldown
    col_widgets = @edit[:new][:col1] +
                  @edit[:new][:col2]
    if @sb[:nodes].length == 2 && @sb[:nodes][1] != "g"
      # default dashboard selected
      @available_widgets = MiqWidget.available_for_all_roles.to_a
    else
      g = MiqGroup.find(@sb[:nodes][2].split('_').first)
      @available_widgets = MiqWidget.available_for_group(g).to_a
    end
    @available_widgets.sort_by! { |w| [w.content_type, w.title.downcase] }

    if @available_widgets.blank?
      @widgets_options = [["No Widgets available to add", "", {"data-icon" => "fa fa-arrow-right"}]]
    else
      @widgets_options = [["Add a Widget", "", {"data-icon" => "fa fa-arrow-right"}]]

      @available_widgets.each do |w|
        next if col_widgets.include?(w.id) || !w.enabled
        image = case w.content_type
                when "chart"
                  "fa fa-pie-chart"
                when "report"
                  "fa fa-file-text-o"
                when "menu"
                  "fa fa-share-square-o"
                end
        @widgets_options.push([w.title, w.id, {"data-icon" => image.to_s}])
      end
    end
    @widgets_options
  end

  def db_move_cols_up
    return unless load_edit("db_edit__seq", "replace_cell__explorer")
    if params[:seq_fields].blank? || params[:seq_fields][0] == ""
      add_flash(_("No fields were selected to move up"), :error)
      @refresh_div = "column_lists"
      @refresh_partial = "db_seq_form"
      return
    end
    consecutive, first_idx, last_idx = db_selected_consecutive?
    if !consecutive
      add_flash(_("Select only one or consecutive fields to move up"), :error)
    else
      if first_idx.positive?
        @edit[:new][:dashboard_order][first_idx..last_idx].reverse_each do |field|
          pulled = @edit[:new][:dashboard_order].delete(field)
          @edit[:new][:dashboard_order].insert(first_idx - 1, pulled)
        end
      end
      @refresh_div = "column_lists"
      @refresh_partial = "db_seq_form"
    end
    @selected = params[:seq_fields]
  end

  def db_move_cols_down
    return unless load_edit("db_edit__seq", "replace_cell__explorer")
    if params[:seq_fields].blank? || params[:seq_fields][0] == ""
      add_flash(_("No fields were selected to move down"), :error)
      @refresh_div = "column_lists"
      @refresh_partial = "db_seq_form"
      return
    end
    consecutive, first_idx, last_idx = db_selected_consecutive?
    if !consecutive
      add_flash(_("Select only one or consecutive fields to move down"), :error)
    else
      if last_idx < @edit[:new][:dashboard_order].length - 1
        insert_idx = last_idx + 1 # Insert before the element after the last one
        insert_idx = -1 if last_idx == @edit[:new][:dashboard_order].length - 2 # Insert at end if 1 away from end
        @edit[:new][:dashboard_order][first_idx..last_idx].each do |field|
          pulled = @edit[:new][:dashboard_order].delete(field)
          @edit[:new][:dashboard_order].insert(insert_idx, pulled)
        end
      end
      @refresh_div = "column_lists"
      @refresh_partial = "db_seq_form"
    end
    @selected = params[:seq_fields]
  end

  def db_selected_consecutive?
    first_idx = last_idx = 0
    @edit[:new][:dashboard_order].each_with_index do |nf, idx|
      first_idx = idx if nf == params[:seq_fields].first
      if nf == params[:seq_fields].last
        last_idx = idx
        break
      end
    end
    if last_idx - first_idx + 1 > params[:seq_fields].length
      return [false, first_idx, last_idx]
    else
      return [true, first_idx, last_idx]
    end
  end
end
