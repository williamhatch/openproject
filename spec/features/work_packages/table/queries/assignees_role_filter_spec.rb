# frozen_string_literal: true

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

require 'spec_helper'

RSpec.describe "Work package filtering",
               "by assignee's role", :js, :with_cuprite do
  shared_let(:project) { create(:project) }

  shared_let(:project_role) { create(:project_role, permissions: %i[view_work_packages work_package_assigned save_queries]) }
  shared_let(:visible_work_package_role) { create(:work_package_role, permissions: %i[view_work_packages work_package_assigned]) }
  shared_let(:invisible_work_package_role) { create(:work_package_role, permissions: %i[view_work_packages]) }
  shared_let(:global_role) { create(:global_role, permissions: %i[view_work_packages work_package_assigned save_queries]) }

  shared_let(:builtin_roles) { [create(:non_member), create(:anonymous_role)] }
  shared_let(:non_assignable_roles) { [invisible_work_package_role] }
  shared_let(:assignable_roles) { [project_role, visible_work_package_role, global_role] }

  shared_let(:other_user) do
    create(:user,
           firstname: 'Other',
           lastname: 'User') do |u|
      u.memberships << create(:member,
                              project:,
                              roles: [project_role])
      u.memberships << create(:member,
                              project:,
                              entity: work_package_user_assignee,
                              roles: [visible_work_package_role])
      u.save!
    end
  end

  shared_let(:work_package_user_assignee) do
    create(:work_package,
           project:,
           assigned_to: other_user)
  end

  let(:wp_table) { Pages::WorkPackagesTable.new(project) }
  let(:filters) { Components::WorkPackages::Filters.new }

  shared_current_user do
    create(:user,
           member_in_project: project,
           member_through_role: project_role,
           global_permissions: %i[view_members])
  end

  it "shows the work package matching the assignee's role to filter" do
    wp_table.visit!
    wp_table.expect_work_package_listed(work_package_user_assignee)

    filters.open
    # It does not show builtin roles such as Anonymous and NonMember or roles that don't allow the user to become an assignee
    filters.expect_missing_filter_value_by("Assignee's role",
                                           'is (OR)',
                                           (builtin_roles + non_assignable_roles),
                                           'assignedToRole')

    filters.add_filter_by("Assignee's role", 'is (OR)', assignable_roles, 'assignedToRole')
    filters.expect_filter_count("2")

    wp_table.expect_work_package_listed(work_package_user_assignee)

    wp_table.save_as('Subject query')

    wp_table.expect_and_dismiss_toaster(message: 'Successful creation.')

    # Revisit query
    wp_table.visit_query Query.last
    wp_table.expect_work_package_listed(work_package_user_assignee)

    filters.open
    # Do not show the already selected roles in the autocomplete dropdown
    filters.expect_missing_autocomplete_value('assignedToRole', assignable_roles)
    filters.expect_filter_by("Assignee's role", 'is (OR)', assignable_roles, 'assignedToRole')
  end
end
