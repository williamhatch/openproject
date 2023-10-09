#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'digest/md5'

module ReportingHelper
  # ======================= SHARED CODE START
  include ApplicationHelper
  include WorkPackagesHelper

  def with_project(project)
    project = Project.find(project) unless project.is_a? Project
    project_was = @project
    @project = project
    yield
    @project = project_was
  end

  def mapped(value, klass, default)
    id = value.to_i
    return default if id < 0

    klass.find(id).name
  end

  def label_for(field)
    name = field.to_s
    if name.starts_with?('label')
      return I18n.t(field)
    end

    name = name.camelcase
    if CostQuery::Filter.const_defined? name
      CostQuery::Filter.const_get(name).label
    elsif
      CostQuery::GroupBy.const_defined? name
      CostQuery::GroupBy.const_get(name).label
    else
      # note that using WorkPackage.human_attribute_name relies on the attribute
      # being an work_package attribute or a general attribute for all models which might not
      # be the case but so far I have only seen the "comments" attribute in reports
      WorkPackage.human_attribute_name(field)
    end
  end

  def debug_fields(result, prefix = ', ')
    prefix << result.fields.inspect << ', ' << result.important_fields.inspect << ', ' << result.key.inspect if params[:debug]
  end

  def month_name(index)
    Date::MONTHNAMES[index].to_s
  end

  # ======================= SHARED CODE END

  def show_field(key, value)
    @show_row ||= Hash.new { |h, k| h[k] = {} }
    @show_row[key][value] ||= field_representation_map(key, value)
  end

  def raw_field(key, value)
    @raw_row ||= Hash.new { |h, k| h[k] = {} }
    @raw_row[key][value] ||= field_sort_map(key, value)
  end

  def budget_link(budget_id)
    budget = Budget.find(budget_id)
    if User.current.allowed_in_project?(:view_budgets, budget.project)
      link_to budget.subject,
              budget_path(budget),
              class: budget.css_classes,
              title: budget.subject
    else
      budget.subject
    end
  end

  def field_representation_map(key, value)
    return I18n.t(:'placeholders.default') if value.blank?

    case key.to_sym
    when :activity_id                           then mapped value, Enumeration, "<i>#{I18n.t(:caption_material_costs)}</i>"
    when :project_id                            then link_to_project Project.find(value.to_i)
    when :user_id, :assigned_to_id, :author_id, :logged_by_id then link_to_user(User.find_by(id: value.to_i) || DeletedUser.first)
    when :tyear, :units                         then h(value.to_s)
    when :tweek                                 then "#{I18n.t(:label_week)} ##{h value}"
    when :tmonth                                then month_name(value.to_i)
    when :category_id                           then h(Category.find(value.to_i).name)
    when :cost_type_id                          then mapped value, CostType, I18n.t(:caption_labor)
    when :budget_id                             then budget_link value
    when :work_package_id                       then link_to_work_package(WorkPackage.find(value.to_i))
    when :spent_on                              then format_date(value.to_date)
    when :type_id                               then h(Type.find(value.to_i).name)
    when :week                                  then "#{I18n.t(:label_week)} #%s" % value.to_i.modulo(100)
    when :priority_id                           then h(IssuePriority.find(value.to_i).name)
    when :version_id                            then h(Version.find(value.to_i).name)
    when :singleton_value                       then ''
    when :status_id                             then h(Status.find(value.to_i).name)
    when /custom_field\d+/                      then custom_value(key, value)
    else h(value.to_s)
    end
  end

  def custom_value(cf_identifier, value)
    cf_id = cf_identifier.gsub('custom_field', '').to_i

    # Reuses rails cache to locate the custom field
    # and then properly cast the value
    CustomValue
      .new(custom_field_id: cf_id, value:)
      .typed_value
  end

  def field_sort_map(key, value)
    return '' if value.blank?

    case key.to_sym
    when :work_package_id, :tweek, :tmonth, :week  then value.to_i
    when :spent_on                                 then value.to_date.mjd
    else strip_tags(field_representation_map(key, value))
    end
  end

  def show_result(row, unit_id = self.unit_id)
    case unit_id
    when -1 then l_hours(row.units)
    when 0  then row.real_costs ? number_to_currency(row.real_costs) : '-'
    else
      current_cost_type = @cost_type || CostType.find(unit_id)
      pluralize(row.units, current_cost_type.unit, current_cost_type.unit_plural)
    end
  end

  def set_filter_options(struct, key, value)
    struct[:operators][key] = '='
    struct[:values][key]    = value.to_s
  end

  def available_cost_type_tabs(cost_types)
    tabs = cost_types.to_a
    tabs.delete 0 # remove money from list
    tabs.unshift 0 # add money as first tab
    tabs.map { |cost_type_id| [cost_type_id, cost_type_label(cost_type_id)] }
  end

  def cost_type_label(cost_type_id, cost_type_inst = nil, _plural = true)
    case cost_type_id
    when -1 then I18n.t(:caption_labor)
    when 0  then I18n.t(:label_money)
    else (cost_type_inst || CostType.find(cost_type_id)).name
    end
  end

  def link_to_details(result)
    return '' # unless result.respond_to? :fields # uncomment to display
    session_filter = { operators: session[:report][:filters][:operators].dup, values: session[:report][:filters][:values].dup }
    filters = result.fields.inject session_filter do |struct, (key, value)|
      key = key.to_sym
      case key
      when :week
        set_filter_options struct, :tweek, value.to_i.modulo(100)
        set_filter_options struct, :tyear, value.to_i / 100
      when :month, :year
        set_filter_options struct, :"t#{key}", value
      when :count, :units, :costs, :display_costs, :sum, :real_costs
      else
        set_filter_options struct, key, value
      end
      struct
    end
    options = { fields: filters[:operators].keys, set_filter: 1, action: :drill_down }
    link_to '[+]', filters.merge(options), class: 'drill_down', title: I18n.t(:description_drill_down)
  end

  ##
  # Create the appropriate action for an entry with the type of log to use
  def action_for(result, options = {})
    options.merge controller: controller_for(result.fields['type']), id: result.fields['id'].to_i
  end

  def controller_for(type)
    type == 'TimeEntry' ? 'timelog' : 'costlog'
  end

  ##
  # Create the appropriate action for an entry with the type of log to use
  def entry_for(result)
    type = result.fields['type'] == 'TimeEntry' ? TimeEntry : CostEntry
    type.find(result.fields['id'].to_i)
  end

  ##
  # For a given row, determine how to render it's contents according to usability and
  # localization rules
  def show_row(row)
    row_text = link_to_details(row) << row.render { |k, v| show_field(k, v) }
    row_text.html_safe
  end

  def delimit(items, options = {})
    options[:step] ||= 1
    options[:delim] ||= '&bull;'
    delimited = []
    items.each_with_index do |item, ix|
      delimited << if ix != 0 && (ix % options[:step]).zero?
                     "<b> #{options[:delim]} </b>" + item
                   else
                     item
                   end
    end
    delimited
  end

  ##
  # Finds the Filter-Class for as specific filter name while being careful with the filter_name parameter as it is user input.
  def filter_class(filter_name)
    klass = CostQuery::Filter.const_get(filter_name.to_s.camelize)
    return klass if klass.is_a? Class

    nil
  rescue NameError
    nil
  end
end
