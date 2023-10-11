require 'spec_helper'

RSpec.describe 'Invalid query spec', js: true do
  let(:user) { create(:admin) }
  let(:project) { create(:project) }

  let(:wp_table) { Pages::WorkPackagesTable.new(project) }
  let(:filters) { Components::WorkPackages::Filters.new }
  let(:group_by) { Components::WorkPackages::GroupBy.new }

  let(:member) do
    create(:member,
           user:,
           project:,
           roles: [create(:project_role)])
  end
  let(:status) do
    create(:status)
  end
  let(:status2) do
    create(:status)
  end

  let(:invalid_query) do
    query = create(:query,
                   project:,
                   user:)

    query.add_filter('assigned_to_id', '=', [99999])
    query.columns << 'cf_0815'
    query.group_by = 'cf_0815'
    query.sort_criteria = [%w(cf_0815 desc)]
    query.save(validate: false)
    create(:view_work_packages_table, query:)

    query
  end

  let(:valid_query) do
    create(:query,
           project:,
           user:)
  end

  let(:work_package_assigned) do
    create(:work_package,
           project:,
           status: status2,
           assigned_to: user)
  end

  before do
    login_as(user)
    status
    status2
    member
    work_package_assigned
  end

  it 'handles invalid queries' do
    # should load a faulty query and also the drop down
    wp_table.visit_query(invalid_query)

    filters.open
    filters.expect_filter_count 1
    filters.expect_no_filter_by('Assignee')
    filters.expect_filter_by('Status', 'open', nil)

    wp_table.expect_no_toaster(type: :error,
                               message: I18n.t('js.work_packages.faulty_query.description'))

    wp_table.expect_work_package_listed work_package_assigned

    wp_table.expect_query_in_select_dropdown(invalid_query.name)

    Capybara.current_session.driver.execute_script('window.localStorage.clear()')

    # should not load with faulty parameters but can be fixed

    filter_props = [{ n: 'assignee', o: '=', v: ['999999'] },
                    { n: 'status', o: '=', v: [status.id.to_s, status2.id.to_s] }]
    column_props = %w(id subject customField0815)
    invalid_props = JSON.dump(f: filter_props,
                              c: column_props,
                              g: 'customField0815',
                              t: 'customField0815:desc')

    wp_table.visit_with_params("query_id=#{valid_query.id}&query_props=#{invalid_props}")

    wp_table.expect_toast(type: :error,
                          message: I18n.t('js.work_packages.faulty_query.description'))
    wp_table.dismiss_toaster!

    wp_table.expect_no_work_package_listed
    filters.expect_filter_count 2

    filters.open
    filters.expect_filter_by('Assignee', 'is (OR)', :placeholder)
    filters.expect_filter_by('Status', 'is (OR)', [status.name, status2.name])

    group_by.enable_via_menu('Assignee')
    sleep(0.3)
    filters.set_filter('Assignee', 'is (OR)', user.name)
    sleep(0.3)

    wp_table.expect_work_package_listed work_package_assigned
    wp_table.save

    wp_table.expect_toast(message: I18n.t('js.notice_successful_update'))
  end
end
