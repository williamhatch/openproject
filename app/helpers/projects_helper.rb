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

module ProjectsHelper
  include WorkPackagesFilterHelper

  def show_filters_section?
    params[:filters].present? && !params.key?(:hide_filters_section)
  end

  def allowed_filters(query)
    query
      .available_filters
      .select { |f| whitelisted_project_filter?(f) }
      .sort_by(&:human_name)
  end

  def whitelisted_project_filter?(filter)
    whitelist = [
      Queries::Projects::Filters::ActiveFilter,
      Queries::Projects::Filters::TemplatedFilter,
      Queries::Projects::Filters::PublicFilter,
      Queries::Projects::Filters::ProjectStatusFilter,
      Queries::Projects::Filters::MemberOfFilter,
      Queries::Projects::Filters::CreatedAtFilter,
      Queries::Projects::Filters::LatestActivityAtFilter,
      Queries::Projects::Filters::NameAndIdentifierFilter,
      Queries::Projects::Filters::TypeFilter
    ]
    whitelist << Queries::Filters::Shared::CustomFields::Base if EnterpriseToken.allows_to?(:custom_fields_in_projects_list)

    whitelist.detect { |clazz| filter.is_a? clazz }
  end

  def no_projects_result_box_params
    if User.current.allowed_globally?(:add_project)
      { action_url: new_project_path, display_action: true }
    else
      {}
    end
  end

  def global_menu_items
    [
      global_menu_all_projects_item,
      global_menu_my_projects_item,
      global_menu_public_projects_item,
      global_menu_archived_projects_item
    ]
  end

  def global_menu_all_projects_item
    path = projects_path

    [
      t(:label_all_projects),
      path,
      { class: global_menu_item_css_class(path),
        title: t(:label_all_projects) }
    ]
  end

  def global_menu_my_projects_item
    path = projects_path_with_filters(
      [{ member_of: { operator: '=', values: ['t'] } }]
    )

    [
      t(:label_my_projects),
      path,
      { class: global_menu_item_css_class(path),
        title: t(:label_my_projects) }
    ]
  end

  def global_menu_public_projects_item
    path = projects_path_with_filters(
      [{ public: { operator: '=', values: ['t'] } }]
    )

    [
      t(:label_public_projects),
      path,
      { class: global_menu_item_css_class(path),
        title: t(:label_public_projects) }
    ]
  end

  def global_menu_archived_projects_item
    path = projects_path_with_filters(
      [{ active: { operator: '=', values: ['f'] } }]
    )

    [
      t(:label_archived_projects),
      path,
      { class: global_menu_item_css_class(path),
        title: t(:label_archived_projects) }
    ]
  end

  def projects_path_with_filters(filters)
    return projects_path if filters.empty?

    projects_path(filters: filters.to_json, hide_filters_section: true)
  end

  def global_menu_item_css_class(path)
    "op-sidemenu--item-action #{global_menu_item_selected(path) ? 'selected' : ''}"
  end

  def global_menu_item_selected(menu_item_path)
    menu_item_path == request.fullpath
  end

  def project_more_menu_items(project)
    [project_more_menu_subproject_item(project),
     project_more_menu_settings_item(project),
     project_more_menu_activity_item(project),
     project_more_menu_archive_item(project),
     project_more_menu_unarchive_item(project),
     project_more_menu_copy_item(project),
     project_more_menu_delete_item(project)].compact
  end

  def project_more_menu_subproject_item(project)
    if User.current.allowed_in_project? :add_subprojects, project
      [t(:label_subproject_new),
       new_project_path(parent_id: project.id),
       { class: 'icon-context icon-add',
         title: t(:label_subproject_new) }]
    end
  end

  def project_more_menu_settings_item(project)
    if User.current.allowed_in_project?({ controller: '/projects/settings/general', action: 'show', project_id: project.id },
                                        project)
      [t(:label_project_settings),
       project_settings_general_path(project),
       { class: 'icon-context icon-settings',
         title: t(:label_project_settings) }]
    end
  end

  def project_more_menu_activity_item(project)
    if User.current.allowed_in_project?(:view_project_activity, project)
      [
        t(:label_project_activity),
        project_activity_index_path(project, event_types: ['project_attributes']),
        { class: 'icon-context icon-checkmark',
          title: t(:label_project_activity) }
      ]
    end
  end

  def project_more_menu_archive_item(project)
    if User.current.allowed_in_project?(:archive_project, project) && project.active?
      [t(:button_archive),
       project_archive_path(project, status: params[:status]),
       { data: { confirm: t('project.archive.are_you_sure', name: project.name) },
         method: :post,
         class: 'icon-context icon-locked',
         title: t(:button_archive) }]
    end
  end

  def project_more_menu_unarchive_item(project)
    if User.current.admin? && project.archived? && (project.parent.nil? || project.parent.active?)
      [t(:button_unarchive),
       project_archive_path(project, status: params[:status]),
       { method: :delete,
         class: 'icon-context icon-unlocked',
         title: t(:button_unarchive) }]
    end
  end

  def project_more_menu_copy_item(project)
    if User.current.allowed_in_project?(:copy_projects, project) && !project.archived?
      [t(:button_copy),
       copy_project_path(project),
       { class: 'icon-context icon-copy',
         title: t(:button_copy) }]
    end
  end

  def project_more_menu_delete_item(project)
    if User.current.admin
      [t(:button_delete),
       confirm_destroy_project_path(project),
       { class: 'icon-context icon-delete',
         title: t(:button_delete) }]
    end
  end

  def project_options_for_status(project)
    contract = if project.new_record?
                 Projects::CreateContract
               else
                 Projects::UpdateContract
               end

    contract
      .new(project, current_user)
      .assignable_status_codes
      .map do |code|
      [I18n.t("activerecord.attributes.project.status_codes.#{code}"), code]
    end
  end

  def project_options_for_templated
    ::Projects::InstantiateTemplateContract
      .visible_templates(current_user)
      .pluck(:name, :id)
  end

  def shorten_text(text, length)
    text.to_s.gsub(/\A(.{#{length}[^\n\r]*).*\z/m, '\1...').strip
  end

  def projects_with_level(projects)
    ancestors = []

    projects.each do |project|
      while !ancestors.empty? && !project.is_descendant_of?(ancestors.last)
        ancestors.pop
      end

      yield project, ancestors.count

      ancestors << project
    end
  end

  def projects_with_levels_order_sensitive(projects, &)
    if sorted_by_lft?
      project_tree(projects, &)
    else
      projects_with_level(projects, &)
    end
  end

  # Just like sort_header tag but removes sorting by
  # lft from the sort criteria as lft is mutually exclusive with
  # the other criteria.
  def projects_sort_header_tag(*)
    former_criteria = @sort_criteria.criteria.dup

    @sort_criteria.criteria.reject! { |a, _| a == 'lft' }

    sort_header_tag(*)
  ensure
    @sort_criteria.criteria = former_criteria
  end

  def sorted_by_lft?
    @sort_criteria.first_key == 'lft'
  end

  def allowed_parent_projects(project)
    if project.persisted?
      Projects::UpdateContract
    else
      Projects::CreateContract
    end.new(project, current_user)
       .assignable_parents
  end

  def gantt_portfolio_query_link(filtered_project_ids)
    generator = ::Projects::GanttQueryGeneratorService.new(filtered_project_ids)
    work_packages_path query_props: generator.call
  end

  def gantt_portfolio_project_ids(project_scope)
    project_scope
      .where(active: true)
      .select(:id)
      .uniq
      .pluck(:id)
  end

  def gantt_portfolio_title
    title = t('projects.index.open_as_gantt_title')

    if current_user.admin?
      title << ' '
      title << t('projects.index.open_as_gantt_title_admin')
    end

    title
  end

  def short_project_description(project, length = 255)
    unless project.description.present?
      return ''
    end

    project.description.gsub(/\A(.{#{length}}[^\n\r]*).*\z/m, '\1...').strip
  end
end
