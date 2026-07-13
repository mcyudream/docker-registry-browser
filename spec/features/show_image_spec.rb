require "rails_helper"

feature "Image details" do
  scenario "Show details of image", :vcr do
    visit "/"

    click_link "hello-world", match: :first

    expect(page).to have_content "镜像仓库"
    expect(page).to have_content "hello-world"
    expect(page).to have_selector "[data-tag-name]", count: 3
    expect(page.all("[data-tag-name]").map { |item| item["data-tag-name"] }).to eq %w[v2 v1 latest]
  end

  scenario "Use custom sort for tags", :vcr do
    visit "/repo/hello-world?sort_tags_by=api&sort_tags_order=asc"

    expect(page.all("[data-tag-name]").map { |item| item["data-tag-name"] }).to eq %w[v2 latest v1]
  end
end
