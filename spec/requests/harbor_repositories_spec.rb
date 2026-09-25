require "rails_helper"

RSpec.describe "Harbor registry" do
  let(:json_headers) { { "Content-Type" => "application/json" } }

  before do
    allow(Rails.configuration.x).to receive(:registry_type).and_return("harbor")
  end

  describe "GET /" do
    before do
      stub_request(:get, "http://localhost:5000/api/v2.0/repositories")
        .with(query: { "page" => "1", "page_size" => "100", "sort" => "-update_time" })
        .to_return(
          status:  200,
          headers: json_headers,
          body:    [ { "name" => "library/busybox", "artifact_count" => 95, "update_time" => "2026-09-25T06:26:25.554Z" } ].to_json
        )
    end

    it "lists the public repositories with their update time" do
      get "/"

      expect(response).to have_http_status :ok
      expect(response.body).to include "busybox"
      expect(response.body).to include "95 个版本"
      expect(response.body).to include "2026-09-25 06:26"
    end
  end

  describe "GET /repo/:name" do
    let(:artifacts) do
      [
        { "digest" => "sha256:abc", "push_time" => "2026-09-14T00:00:00.000Z", "tags" => [ { "name" => "latest" } ] },
        { "digest" => "sha256:def", "push_time" => "2026-09-01T00:00:00.000Z", "tags" => [ { "name" => "v1" } ] },
        { "digest" => "sha256:ghi", "push_time" => "2026-09-20T00:00:00.000Z", "tags" => [ { "name" => "stable" } ] }
      ]
    end

    before do
      stub_request(:get, "http://localhost:5000/api/v2.0/projects/library/repositories/busybox/artifacts")
        .with(query: hash_including("with_tag" => "true", "sort" => "-push_time"))
        .to_return(status: 200, headers: json_headers, body: artifacts.to_json)
    end

    it "lists the tags with their push times" do
      get "/repo/library/busybox"

      expect(response).to have_http_status :ok
      expect(tag_names).to eq %w[v1 stable latest] # default: name, descending
      expect(response.body).to include "2026-09-14 00:00"
    end

    context "when sorted by push time" do
      it "orders the tags from newest to oldest by default" do
        get "/repo/library/busybox", params: { sort_tags_by: "time" }

        expect(tag_names).to eq %w[stable latest v1]
      end

      it "orders the tags from oldest to newest when ascending" do
        get "/repo/library/busybox", params: { sort_tags_by: "time", sort_tags_order: "asc" }

        expect(tag_names).to eq %w[v1 latest stable]
      end

      it "offers the push time option in the sort links" do
        get "/repo/library/busybox", params: { sort_tags_by: "time" }

        expect(response.body).to include "推送时间"
      end
    end
  end

  private

  def tag_names
    response.body.scan(/data-tag-name="([^"]+)"/).flatten
  end
end
