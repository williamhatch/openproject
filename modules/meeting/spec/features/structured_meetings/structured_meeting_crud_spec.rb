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

require_relative '../../support/pages/meetings/new'
require_relative '../../support/pages/structured_meeting/show'

# Cuprite has a bug where it sends keydown events without #key property
# This breaks stimulus handling of the escape action
# https://github.com/rubycdp/cuprite/issues/240
RSpec.describe 'Structured meetings CRUD',
               :js,
               with_cuprite: false do
  include Components::Autocompleter::NgSelectAutocompleteHelpers

  shared_let(:project) { create(:project, enabled_module_names: %w[meetings work_package_tracking]) }
  shared_let(:user) do
    create(:user,
           lastname: 'First',
           member_in_project: project,
           member_with_permissions: %i[view_meetings create_meetings edit_meetings delete_meetings view_work_packages]).tap do |u|
      u.pref[:time_zone] = 'utc'

      u.save!
    end
  end
  shared_let(:other_user) do
    create(:user,
           lastname: 'Second',
           member_in_project: project,
           member_with_permissions: %i[view_meetings view_work_packages])
  end
  shared_let(:no_member_user) do
    create(:user,
           lastname: 'Third')
  end
  shared_let(:work_package) do
    create(:work_package, project:, subject: 'Important task')
  end

  let(:current_user) { user }
  let(:new_page) { Pages::Meetings::New.new(project) }
  let(:show_page) { Pages::StructuredMeeting::Show.new(StructuredMeeting.order(id: :asc).last) }

  before do
    login_as current_user
    new_page.visit!
    expect(page).to have_current_path(new_page.path)
    new_page.set_title 'Some title'
    new_page.set_type 'Dynamic'

    new_page.set_start_date '2013-03-28'
    new_page.set_start_time '13:30'
    new_page.set_duration '1.5'
    new_page.invite(other_user)

    new_page.click_create
  end

  it 'can create a structured meeting and add agenda items' do
    show_page.expect_toast(message: 'Successful creation')

    # Can add and edit a single item
    show_page.add_agenda_item do
      fill_in 'Title', with: 'My agenda item'
      fill_in 'Duration in minutes', with: '25'
    end

    show_page.expect_agenda_item title: 'My agenda item'
    show_page.cancel_add_form

    item = MeetingAgendaItem.find_by(title: 'My agenda item')
    show_page.edit_agenda_item(item) do
      fill_in 'Title', with: 'Updated title'
      click_button 'Save'
    end

    show_page.expect_no_agenda_item title: 'My agenda item'

    # Can add multiple items
    show_page.add_agenda_item do
      fill_in 'Title', with: 'First'
    end

    show_page.expect_agenda_item title: 'Updated title'
    show_page.expect_agenda_item title: 'First'

    show_page.in_agenda_form do
      fill_in 'Title', with: 'Second'
      click_button 'Save'
    end

    show_page.expect_agenda_item title: 'Updated title'
    show_page.expect_agenda_item title: 'First'
    show_page.expect_agenda_item title: 'Second'

    # Can reorder
    show_page.assert_agenda_order! 'Updated title', 'First', 'Second'

    second = MeetingAgendaItem.find_by!(title: 'Second')
    show_page.select_action(second, I18n.t(:label_sort_higher))
    show_page.assert_agenda_order! 'Updated title', 'Second', 'First'

    first = MeetingAgendaItem.find_by!(title: 'First')
    show_page.select_action(first, I18n.t(:label_sort_highest))
    show_page.assert_agenda_order! 'First', 'Updated title', 'Second'

    # Can edit and cancel with escape
    show_page.edit_agenda_item(first) do
      find_field('Title').send_keys :escape
    end
    show_page.expect_item_edit_form(first, visible: false)

    # Can remove
    show_page.remove_agenda_item first
    show_page.assert_agenda_order! 'Updated title', 'Second'

    # Can link work packages
    show_page.add_agenda_item(type: WorkPackage) do
      select_autocomplete(find_test_selector('op-agenda-items-wp-autocomplete'),
                          query: 'task',
                          results_selector: 'body')
    end

    show_page.expect_agenda_link work_package
    wp_item = MeetingAgendaItem.find_by!(work_package_id: work_package.id)
    expect(wp_item).to be_present

    # user can see actions
    expect(page).to have_selector('#meeting-agenda-items-new-button-component')
    expect(page).to have_test_selector('op-meeting-agenda-actions', count: 3)

    # other_use can view, but not edit
    login_as other_user
    show_page.visit!

    expect(page).not_to have_selector('#meeting-agenda-items-new-button-component')
    expect(page).not_to have_test_selector('op-meeting-agenda-actions')
  end

  it 'can delete a meeting and get back to the index page' do
    click_button('op-meetings-header-action-trigger')

    accept_confirm(I18n.t('text_are_you_sure')) do
      click_button 'Delete meeting'
    end

    expect(page).to have_current_path project_meetings_path(project)
  end

  context 'exporting as ICS' do
    before do
      @download_list = DownloadList.new
    end

    after do
      DownloadList.clear
    end

    subject { @download_list.refresh_from(page).latest_download.to_s }

    it 'can export the meeting as ICS' do
      click_button('op-meetings-header-action-trigger')

      click_link I18n.t(:label_icalendar_download)

      expect(subject).to end_with ".ics"
    end
  end

  context 'with a work package reference to another' do
    let!(:meeting) { create(:structured_meeting, project:, author: current_user) }
    let!(:other_project) { create(:project) }
    let!(:other_wp) { create(:work_package, project: other_project, author: current_user, subject: 'Private task') }
    let!(:role) { create(:project_role, permissions: %w[view_work_packages]) }
    let!(:membership) { create(:member, principal: user, project: other_project, roles: [role]) }
    let!(:agenda_item) { create(:meeting_agenda_item, meeting:, author: current_user, work_package: other_wp) }
    let(:show_page) { Pages::StructuredMeeting::Show.new(meeting) }

    it 'shows correctly for author, but returns an unresolved reference for the second user' do
      show_page.visit!
      show_page.expect_agenda_link agenda_item
      expect(page).to have_text 'Private task'

      login_as other_user

      show_page.visit!
      show_page.expect_undisclosed_agenda_link agenda_item
      expect(page).not_to have_text 'Private task'
    end
  end
end
