require 'rails_helper'

feature 'Token Auth' do
  include TokenAuthHelpers

  before do
    configure_token_auth
    stub_token_auth_requests
  end

  scenario 'Successful listing empty catalog' do
    stub_catalog_requests [
      token_auth_required_response,
      empty_catalog_response
    ]

    visit '/'

    expect(page).to have_text '仓库连接正常，但镜像目录目前为空。'
  end

  scenario 'Failed listing of catalog due to ACL issue' do
    stub_catalog_requests [ token_auth_required_response ]

    visit '/'

    expect(page).to have_text '镜像仓库拒绝了当前访问令牌。'
  end

  scenario 'Successful listing of catalog and repository' do
    stub_catalog_requests [ token_auth_required_response, successful_catalog_response ]
    stub_repository_requests [ token_auth_required_response, successful_repository_response ]

    visit '/'
    click_link 'repository'

    expect(page).to have_text '镜像仓库'
    expect(page).to have_text 'repository'
    expect(page).to have_text 'TAG'
    expect(page).to have_text 'latest'
  end

  scenario 'Successful listing of catalog but failed request of repository' do
    stub_catalog_requests [ token_auth_required_response, successful_catalog_response ]
    stub_repository_requests [ token_auth_required_response ]

    visit '/'
    click_link 'repository'

    expect(page).to have_text '镜像仓库拒绝了当前访问令牌。'
  end
end
