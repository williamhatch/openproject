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
require_relative '../../../support/bcf_topic_with_stubbed_comment'

RSpec.describe API::V3::Activities::ActivityRepresenter do
  include API::Bim::Utilities::PathHelper

  let(:user) { build_stubbed(:user) }
  let(:other_user) { build_stubbed(:user) }
  let(:project) do
    work_package.project
  end
  let(:work_package) do
    journal.journable.tap do |wp|
      allow(wp)
        .to receive(:bcf_issue)
        .and_return(bcf_topic)
    end
  end
  let(:journal) do
    build_stubbed(:work_package_journal).tap do |journal|
      allow(journal)
        .to receive(:get_changes)
        .and_return(changes)
      allow(journal)
        .to receive(:bcf_comment)
        .and_return(bcf_comment)
    end
  end
  let(:changes) { { subject: ["first subject", "second subject"] } }
  let(:representer) { described_class.new(journal, current_user: user) }

  before do
    mock_permissions_for(user) do |mock|
      mock.in_project :view_linked_issues, :edit_work_package_notes, :add_work_packages, project:
    end

    login_as(user)
  end

  include_context 'bcf_topic with stubbed comment'

  subject(:generated) { representer.to_json }

  describe 'type' do
    context 'if a bcf_comment is present' do
      let(:notes) { '' }

      it 'is Activity::BcfComment' do
        expect(subject)
          .to be_json_eql('Activity::BcfComment'.to_json)
          .at_path('_type')
      end
    end
  end

  describe '_links' do
    describe 'bcfViewpoints' do
      context 'if a viewpoint is present' do
        it_behaves_like 'has a link collection' do
          let(:link) { 'bcfViewpoints' }
          let(:hrefs) do
            [
              {
                href: bcf_v2_1_paths.viewpoint(work_package.project.identifier, bcf_topic.uuid, bcf_topic.viewpoints[0].uuid)
              }
            ]
          end
        end

        context 'if no comment is present' do
          let(:bcf_comment) { nil }

          it_behaves_like 'has no link' do
            let(:link) { 'bcfViewpoints' }
          end
        end

        context 'if no viewpoint is linked' do
          before do
            allow(bcf_comment)
              .to receive(:viewpoint)
              .and_return nil
          end

          it_behaves_like 'has a link collection' do
            let(:link) { 'bcfViewpoints' }
            let(:hrefs) do
              []
            end
          end
        end

        context 'if permission is lacking' do
          before do
            mock_permissions_for(user, &:forbid_everything!)
          end

          it_behaves_like 'has no link' do
            let(:link) { 'bcfViewpoints' }
          end
        end
      end
    end
  end
end
