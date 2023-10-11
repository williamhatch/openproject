# frozen_string_literal: true

# -- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2010-2023 the OpenProject GmbH
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
# ++

require 'spec_helper'

RSpec.describe 'Work package sharing',
               :js,
               :with_cuprite,
               with_flag: { work_package_sharing: true } do
  shared_let(:view_work_package_role) { create(:view_work_package_role) }
  shared_let(:comment_work_package_role) { create(:comment_work_package_role) }
  shared_let(:edit_work_package_role) { create(:edit_work_package_role) }

  shared_let(:view_user) { create(:user, firstname: 'View', lastname: 'User') }
  shared_let(:comment_user) { create(:user, firstname: 'Comment', lastname: 'User') }
  shared_let(:edit_user) { create(:user, firstname: 'Edit', lastname: 'User') }
  shared_let(:non_shared_project_user) { create(:user, firstname: 'Non Shared Project', lastname: 'User') }
  shared_let(:shared_project_user) { create(:user, firstname: 'Shared Project', lastname: 'User') }
  shared_let(:not_shared_yet_with_user) { create(:user, firstname: 'Not shared Yet', lastname: 'User') }

  shared_let(:richard) { create(:user, firstname: 'Richard', lastname: 'Hendricks') }
  shared_let(:dinesh) { create(:user, firstname: 'Dinesh', lastname: 'Chugtai') }
  shared_let(:gilfoyle) { create(:user, firstname: 'Bertram', lastname: 'Gilfoyle') }
  shared_let(:not_shared_yet_with_group) { create(:group, members: [richard, dinesh, gilfoyle]) }

  let(:project) do
    create(:project,
           members: { current_user => [sharer_role],
                      # The roles of those users don't really matter, reusing the roles
                      # to save some creation work.
                      non_shared_project_user => [sharer_role],
                      shared_project_user => [sharer_role] })
  end
  let(:sharer_role) do
    create(:project_role,
           permissions: %i(view_work_packages
                           view_shared_work_packages
                           share_work_packages))
  end
  let(:work_package) do
    create(:work_package, project:) do |wp|
      create(:work_package_member, entity: wp, user: view_user, roles: [view_work_package_role])
      create(:work_package_member, entity: wp, user: comment_user, roles: [comment_work_package_role])
      create(:work_package_member, entity: wp, user: edit_user, roles: [edit_work_package_role])
      create(:work_package_member, entity: wp, user: shared_project_user, roles: [edit_work_package_role])
      create(:work_package_member, entity: wp, user: current_user, roles: [view_work_package_role])
      create(:work_package_member, entity: wp, user: dinesh, roles: [edit_work_package_role])
    end
  end
  let(:work_package_page) { Pages::FullWorkPackage.new(work_package) }
  let(:share_modal) { Components::WorkPackages::ShareModal.new(work_package) }

  current_user { create(:user, firstname: 'Signed in', lastname: 'User') }

  def shared_principals
    Principal.where(id: Member.of_work_package(work_package).select(:user_id))
  end

  def inherited_member_roles(group:)
    MemberRole.where(inherited_from: MemberRole.where(member_id: group.memberships))
  end

  context 'when having share permission' do
    it 'allows seeing and administrating sharing' do
      work_package_page.visit!

      # Clicking on the share button opens a modal which lists all of the users a work package
      # is explicitly shared with.
      # Project members are not listed unless the work package is also shared with them explicitly.
      click_button 'Share'

      aggregate_failures "Initial shares list" do
        share_modal.expect_open
        share_modal.expect_shared_with(comment_user, 'Comment', position: 1)
        share_modal.expect_shared_with(dinesh, 'Edit', position: 2)
        share_modal.expect_shared_with(edit_user, 'Edit', position: 3)
        share_modal.expect_shared_with(shared_project_user, 'Edit', position: 4)
        # The current users share is also displayed but not editable
        share_modal.expect_shared_with(current_user, position: 5, editable: false)
        share_modal.expect_shared_with(view_user, 'View', position: 6)

        share_modal.expect_not_shared_with(non_shared_project_user)
        share_modal.expect_not_shared_with(not_shared_yet_with_user)

        share_modal.expect_shared_count_of(6)
      end

      aggregate_failures "Inviting a user for the first time" do
        # Inviting a user will lead to that user being prepended to the list together with the rest of the shared with users.
        share_modal.invite_user(not_shared_yet_with_user, 'View')

        share_modal.expect_shared_with(not_shared_yet_with_user, 'View', position: 1)
        share_modal.expect_shared_count_of(7)
      end

      aggregate_failures "Removing a user" do
        # Removing a share will lead to that user being removed from the list of shared with users.
        share_modal.remove_user(edit_user)
        share_modal.expect_not_shared_with(edit_user)
        share_modal.expect_shared_count_of(6)
      end

      aggregate_failures "Re-inviting a user" do
        # Adding a user multiple times will lead to the user's role being updated.
        share_modal.invite_user(not_shared_yet_with_user, 'Edit')
        share_modal.expect_shared_with(not_shared_yet_with_user, 'Edit', position: 1)
        share_modal.expect_shared_count_of(6)

        # Sent out email only on first share and not again when updating.
        perform_enqueued_jobs
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      end

      aggregate_failures "Updating a share" do
        # Updating the share
        share_modal.change_role(not_shared_yet_with_user, 'Comment')
        share_modal.expect_shared_with(not_shared_yet_with_user, 'Comment', position: 1)
        share_modal.expect_shared_count_of(6)

        # Sent out email only on first share and not again when updating so the
        # count should still be 1.
        perform_enqueued_jobs
        expect(ActionMailer::Base.deliveries.size).to eq(1)
      end

      share_modal.close
      click_button 'Share'

      aggregate_failures "Inviting a group" do
        # Inviting a group propagates the membership to the group's users. However, these propagated
        # memberships are not expected to be visible.
        share_modal.invite_group(not_shared_yet_with_group, 'View')
        share_modal.expect_shared_with(not_shared_yet_with_group, 'View', position: 1)

        # This user has a share independent of the group's share. Hence, that Role prevails
        share_modal.expect_shared_with(dinesh, 'Edit')
        share_modal.expect_not_shared_with(richard)
        share_modal.expect_not_shared_with(gilfoyle)

        share_modal.expect_shared_count_of(7)

        expect(shared_principals)
          .to include(not_shared_yet_with_group,
                      richard,
                      gilfoyle,
                      dinesh)

        perform_enqueued_jobs
        # Sent out an email only to the group members that weren't already
        # previously shared the work package (richard and gilfoyle), so count increased to 3
        expect(ActionMailer::Base.deliveries.size).to eq(3)
      end

      aggregate_failures "Inviting a group member with its own independent role" do
        # Inviting a group user to a Work Package independently of the the group displays
        # said user in the shares list
        share_modal.invite_user(gilfoyle, 'Comment')
        share_modal.expect_shared_with(gilfoyle, 'Comment', position: 1)
        share_modal.expect_shared_count_of(8)

        perform_enqueued_jobs
        # No emails sent out since the user was already previously invited via the group.
        # Hence, count should remain at 3
        expect(ActionMailer::Base.deliveries.size).to eq(3)
      end

      aggregate_failures "Updating a group's share" do
        # Updating a group's share role also propagates to the inherited member roles of
        # its users
        share_modal.change_role(not_shared_yet_with_group, 'Comment')
        share_modal.expect_shared_count_of(8)
        expect(inherited_member_roles(group: not_shared_yet_with_group))
          .to all(have_attributes(role: comment_work_package_role))

        perform_enqueued_jobs
        # No emails sent out on updates
        expect(ActionMailer::Base.deliveries.size).to eq(3)
      end

      aggregate_failures "Removing a group share" do
        # When removing a group's share, its users also get their inherited member roles removed
        # while keeping member roles that were granted independently of the group
        share_modal.remove_user(not_shared_yet_with_group)
        share_modal.expect_not_shared_with(not_shared_yet_with_group)
        share_modal.expect_not_shared_with(richard)
        share_modal.expect_shared_with(dinesh, 'Edit')
        share_modal.expect_shared_with(gilfoyle, 'Comment')
        share_modal.expect_shared_count_of(7)

        expect(inherited_member_roles(group: not_shared_yet_with_group))
          .to be_empty

        expect(shared_principals)
          .to include(gilfoyle, dinesh)
        expect(shared_principals)
          .not_to include(not_shared_yet_with_group, richard)
      end

      share_modal.close
      click_button 'Share'

      aggregate_failures "Re-opening the modal after changes performed" do
        # This user preserved its group independent share
        share_modal.expect_shared_with(gilfoyle, 'Comment', position: 1)
        share_modal.expect_shared_with(comment_user, 'Comment', position: 2)
        # This user preserved its group independent share
        share_modal.expect_shared_with(dinesh, 'Edit', position: 3)
        # This user's role was updated
        share_modal.expect_shared_with(not_shared_yet_with_user, 'Comment', position: 4)
        # These users were not changed
        share_modal.expect_shared_with(shared_project_user, 'Edit', position: 5)
        share_modal.expect_shared_with(current_user, position: 6, editable: false)
        share_modal.expect_shared_with(view_user, 'View', position: 7)

        # This group's share was revoked
        share_modal.expect_not_shared_with(not_shared_yet_with_group)
        # This user's share was revoked via its group
        share_modal.expect_not_shared_with(richard)
        # This user's share was revoked
        share_modal.expect_not_shared_with(edit_user)
        # This user has never been added
        share_modal.expect_not_shared_with(non_shared_project_user)

        share_modal.expect_shared_count_of(7)
      end
    end
  end

  context 'when lacking share permission' do
    let(:sharer_role) do
      create(:project_role,
             permissions: %i(view_work_packages
                             view_shared_work_packages))
    end

    it 'allows seeing shares but not editing' do
      work_package_page.visit!

      # Clicking on the share button opens a modal which lists all of the users a work package
      # is explicitly shared with.
      # Project members are not listed unless the work package is also shared with them explicitly.
      click_button 'Share'

      share_modal.expect_open
      share_modal.expect_shared_with(view_user, editable: false)
      share_modal.expect_shared_with(comment_user, editable: false)
      share_modal.expect_shared_with(dinesh, editable: false)
      share_modal.expect_shared_with(edit_user, editable: false)
      share_modal.expect_shared_with(shared_project_user, editable: false)
      share_modal.expect_shared_with(current_user, editable: false)

      share_modal.expect_not_shared_with(non_shared_project_user)
      share_modal.expect_not_shared_with(not_shared_yet_with_user)

      share_modal.expect_shared_count_of(6)

      share_modal.expect_no_invite_option
    end
  end
end
