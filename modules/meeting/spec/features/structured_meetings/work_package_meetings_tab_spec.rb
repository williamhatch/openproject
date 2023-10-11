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
require_relative '../../support/pages/work_package_meetings_tab'

RSpec.describe 'Open the Meetings tab', :js do
  let(:user) do
    create(:user,
           member_in_project: project,
           member_through_role: role)
  end
  let(:role) do
    create(:project_role,
           permissions: %i(view_work_packages
                           view_meetings
                           edit_meetings))
  end
  let(:project) { create(:project) }
  let(:work_package) { create(:work_package, project:, subject: 'A test work_package') }
  let(:meetings_tab) { Pages::MeetingsTab.new(work_package.id) }

  let(:tabs) { Components::WorkPackages::Tabs.new(work_package) }
  let(:meetings_tab_element) { find('.op-tab-row--link_selected', text: 'MEETINGS') }

  shared_context "a meetings tab" do
    before do
      login_as(user)
    end

    it 'shows the meetings tab when the user is allowed to see it' do
      work_package_page.visit!
      work_package_page.switch_to_tab(tab: 'meetings')

      meetings_tab.expect_tab_content_rendered
    end

    context 'when the user does not have the permissions to see the meetings tab' do
      let(:role) do
        create(:project_role,
               permissions: %i(view_work_packages))
      end

      it 'does not show the meetings tab' do
        work_package_page.visit!

        meetings_tab.expect_tab_not_present
      end
    end

    context 'when the meetings module is not enabled for the project' do
      let(:project) { create(:project, disable_modules: 'meetings') }

      it 'does not show the meetings tab' do
        work_package_page.visit!

        meetings_tab.expect_tab_not_present
      end
    end

    context 'when the work_package is not referenced in an upcoming meeting' do
      it 'shows an empty message within the upcoming meetings section' do
        work_package_page.visit!
        switch_to_meetings_tab

        meetings_tab.expect_upcoming_counter_to_be(0)

        expect(page).to have_content('This work package is not scheduled in an upcoming meeting agenda yet.')
      end
    end

    context 'when the work_package is not referenced in a past meeting' do
      it 'shows an empty message within the past meetings section' do
        work_package_page.visit!
        switch_to_meetings_tab

        meetings_tab.expect_past_counter_to_be(0)
        meetings_tab.switch_to_past_meetings_section

        expect(page).to have_content('This work package was not mentioned in a past meeting.')
      end
    end

    context 'when the work_package is already referenced in upcoming meetings' do
      let!(:first_meeting) { create(:structured_meeting, project:) }
      let!(:second_meeting) { create(:structured_meeting, project:) }

      let!(:first_meeting_agenda_item_of_first_meeting) do
        create(:meeting_agenda_item, meeting: first_meeting, work_package:, notes: "A very important note in first meeting!")
      end
      let!(:second_meeting_agenda_item_of_first_meeting) do
        create(:meeting_agenda_item, meeting: first_meeting, work_package:,
                                     notes: "Another very important note in the first meeting!")
      end
      let!(:meeting_agenda_item_of_second_meeting) do
        create(:meeting_agenda_item, meeting: second_meeting, work_package:,
                                     notes: "A very important note in the second meeting!")
      end

      it 'shows the meeting agenda items in the upcoming meetings section grouped by meeting' do
        work_package_page.visit!
        switch_to_meetings_tab

        meetings_tab.expect_upcoming_counter_to_be(2)
        meetings_tab.expect_past_counter_to_be(0)

        page.within_test_selector("op-meeting-container-#{first_meeting.id}") do
          expect(page).to have_content(first_meeting.title)
          expect(page).to have_content(first_meeting_agenda_item_of_first_meeting.notes)
          expect(page).to have_content(second_meeting_agenda_item_of_first_meeting.notes)
        end

        page.within_test_selector("op-meeting-container-#{second_meeting.id}") do
          expect(page).to have_content(second_meeting.title)
          expect(page).to have_content(meeting_agenda_item_of_second_meeting.notes)
        end
      end
    end

    context 'when the work_package was already referenced in past meetings' do
      let!(:first_past_meeting) { create(:structured_meeting, project:, start_time: Date.yesterday - 10.hours) }
      let!(:second_past_meeting) { create(:structured_meeting, project:, start_time: Date.yesterday - 10.hours) }

      let!(:first_meeting_agenda_item_of_first_past_meeting) do
        create(:meeting_agenda_item, meeting: first_past_meeting, work_package:, notes: "A very important note in first meeting!")
      end
      let!(:second_meeting_agenda_item_of_first_past_meeting) do
        create(:meeting_agenda_item, meeting: first_past_meeting, work_package:,
                                     notes: "Another very important note in the first meeting!")
      end
      let!(:meeting_agenda_item_of_second_past_meeting) do
        create(:meeting_agenda_item, meeting: second_past_meeting, work_package:,
                                     notes: "A very important note in the second meeting!")
      end

      it 'shows the meeting agenda items in the past meetings section grouped by meeting' do
        work_package_page.visit!
        switch_to_meetings_tab

        meetings_tab.expect_upcoming_counter_to_be(0)
        meetings_tab.expect_past_counter_to_be(2)

        meetings_tab.switch_to_past_meetings_section

        page.within_test_selector("op-meeting-container-#{first_past_meeting.id}") do
          expect(page).to have_content(first_past_meeting.title)
          expect(page).to have_content(first_meeting_agenda_item_of_first_past_meeting.notes)
          expect(page).to have_content(second_meeting_agenda_item_of_first_past_meeting.notes)
        end

        page.within_test_selector("op-meeting-container-#{second_past_meeting.id}") do
          expect(page).to have_content(second_past_meeting.title)
          expect(page).to have_content(meeting_agenda_item_of_second_past_meeting.notes)
        end
      end
    end

    context 'when user is allowed to edit meetings' do
      it 'shows the add to meeting button' do
        work_package_page.visit!
        switch_to_meetings_tab

        meetings_tab.expect_add_to_meeting_button_present
      end

      it 'opens the add to meeting dialog when clicking the add to meeting button' do
        work_package_page.visit!
        switch_to_meetings_tab

        meetings_tab.open_add_to_meeting_dialog

        meetings_tab.expect_add_to_meeting_dialog_shown
      end

      context 'when open, upcoming meetings are visible for the user' do
        let!(:past_meeting) { create(:structured_meeting, project:, start_time: Date.yesterday - 10.hours) }
        let!(:first_upcoming_meeting) { create(:structured_meeting, project:) }
        let!(:second_upcoming_meeting) { create(:structured_meeting, project:) }
        let!(:closed_upcoming_meeting) { create(:structured_meeting, project:, state: :closed) }

        it 'enables the user to add the work package to multiple open, upcoming meetings' do
          work_package_page.visit!
          switch_to_meetings_tab

          meetings_tab.expect_upcoming_counter_to_be(0)

          meetings_tab.open_add_to_meeting_dialog

          meetings_tab.fill_and_submit_meeting_dialog(
            first_upcoming_meeting,
            'A very important note added from the meetings tab to the first meeting!'
          )

          meetings_tab.expect_upcoming_counter_to_be(1)

          page.within_test_selector("op-meeting-container-#{first_upcoming_meeting.id}") do
            expect(page).to have_content('A very important note added from the meetings tab to the first meeting!')
          end

          meetings_tab.open_add_to_meeting_dialog

          meetings_tab.fill_and_submit_meeting_dialog(
            second_upcoming_meeting,
            'A very important note added from the meetings tab to the second meeting!'
          )

          meetings_tab.expect_upcoming_counter_to_be(2)

          page.within_test_selector("op-meeting-container-#{second_upcoming_meeting.id}") do
            expect(page).to have_content('A very important note added from the meetings tab to the second meeting!')
          end
        end

        it 'does not enable the user to select a past meeting' do
          work_package_page.visit!
          switch_to_meetings_tab

          meetings_tab.open_add_to_meeting_dialog

          fill_in('meeting_agenda_item_meeting_id', with: past_meeting.title)
          expect(page).not_to have_selector('.ng-option-marked', text: past_meeting.title)
        end

        it 'does not enable the user to select a closed, upcoming meeting' do
          work_package_page.visit!
          switch_to_meetings_tab

          meetings_tab.open_add_to_meeting_dialog

          fill_in('meeting_agenda_item_meeting_id', with: closed_upcoming_meeting.title)
          expect(page).not_to have_selector('.ng-option-marked', text: closed_upcoming_meeting.title)
        end

        it 'requires a meeting to be selected' do
          work_package_page.visit!
          switch_to_meetings_tab

          meetings_tab.open_add_to_meeting_dialog

          click_button('Save')

          expect(page).to have_content('Meeting can\'t be blank')
        end
      end
    end

    context 'when user is not allowed to edit meetings' do
      let(:restricted_role) do
        create(:project_role,
               permissions: %i(view_work_packages
                               view_meetings)) # edit_meetings is missing
      end
      let(:user) do
        create(:user,
               member_in_project: project,
               member_through_role: restricted_role)
      end

      it 'does not show the add to meeting button' do
        work_package_page.visit!
        switch_to_meetings_tab

        meetings_tab.expect_add_to_meeting_button_not_present
      end
    end
  end

  describe 'work package full view' do
    let(:work_package_page) { Pages::FullWorkPackage.new(work_package) }

    it_behaves_like 'a meetings tab'
  end

  describe 'work package split view' do
    let(:work_package_page) { Pages::SplitWorkPackage.new(work_package) }

    it_behaves_like 'a meetings tab'
  end

  def switch_to_meetings_tab
    work_package_page.switch_to_tab(tab: 'meetings')
    meetings_tab.expect_tab_content_rendered # wait for the tab to be rendered
  end
end
