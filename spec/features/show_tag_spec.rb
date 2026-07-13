require "rails_helper"

feature "Tag details" do
  shared_examples_for "successful showing an image tag" do
    scenario "Show details of tag", :vcr do
      visit "/repo/test/hello-world"

      click_link "latest"

      expect(page).to have_content "镜像详情"
      expect(page).to have_content "hello-world:latest"

      expect(page).to have_content "内容摘要"
      expect(page).to have_content(/sha256:[0-9a-f]{64}/)

      expect(page).to have_content "镜像大小"
      expect(page).to have_content "743 KB"

      expect(page).to have_content "环境变量"
      expect(page).to have_content "IMAGE"
      expect(page).to have_content "test/hello-world:latest"

      expect(page).to have_content "镜像标签"
      expect(page).to have_content "image"
      expect(page).to have_content "test/hello-world:latest"
      expect(page).to have_content "maintainer"
      expect(page).to have_content "Somebody"

      expect(page).to have_content "镜像层"
      expect(page).to have_content(/#000\s*sha256:[0-9a-f]{64}/)
    end
  end

  context "when the manifest is in oci v1 format" do
    include_examples "successful showing an image tag"
  end

  context "when the manifest is in docker v2 format" do
    include_examples "successful showing an image tag"
  end

  context "when the manifest is a list" do
    scenario "Show multiple manifests as tabs", :vcr do
      visit "/repo/test/hello-world"

      click_link "v1"

      expect(page).to have_content "linux / arm64"
      expect(page).to have_content "linux / amd64"
    end
  end
end
