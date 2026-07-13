require "rails_helper"

feature "Delete Tags" do
  background do
    allow(Rails.configuration.x).to receive(:delete_enabled).and_return(true)
  end

  scenario "Successfully delete a tag", :vcr do
    visit "/repo/hello-world/tag/delete-me"

    expect(page).to have_content "镜像详情"
    expect(page).to have_content "hello-world:delete-me"

    expect(page).to have_content "危险操作"
    within ".border-danger" do
      click_button "删除"
    end

    expect(page).to have_selector("#delete-dialog", visible: true)
    expect(page).to have_content "即将删除以下镜像标签"
    fill_in "delete_confirm", with: "delete-me"
    within "#delete-dialog" do
      click_link "确认删除"
    end

    expect(page).to have_content "镜像标签 delete-me 已删除。"
  end

  scenario "Successfully delete a tag with token based auth", :vcr do
    allow(Rails.configuration.x).to receive(:token_auth_user).and_return('admin')
    allow(Rails.configuration.x).to receive(:token_auth_password).and_return('password')

    visit "/repo/hello-world/tag/delete-me"

    expect(page).to have_content "镜像详情"
    expect(page).to have_content "hello-world:delete-me"

    expect(page).to have_content "危险操作"
    within ".border-danger" do
      click_button "删除"
    end

    expect(page).to have_selector("#delete-dialog", visible: true)
    expect(page).to have_content "即将删除以下镜像标签"
    fill_in "delete_confirm", with: "delete-me"
    within "#delete-dialog" do
      click_link "确认删除"
    end

    expect(page).to have_content "镜像标签 delete-me 已删除。"
  end

  scenario "Deletion blocked by registry", :vcr do
    visit "/repo/hello-world/tag/delete-me"

    expect(page).to have_content "镜像详情"
    expect(page).to have_content "hello-world:delete-me"

    expect(page).to have_content "危险操作"
    within ".border-danger" do
      click_button "删除"
    end

    expect(page).to have_selector("#delete-dialog", visible: true)
    expect(page).to have_content "即将删除以下镜像标签"
    fill_in "delete_confirm", with: "delete-me"
    within "#delete-dialog" do
      click_link "确认删除"
    end

    expect(page).to have_content "镜像仓库拒绝了删除请求。"
  end
end
