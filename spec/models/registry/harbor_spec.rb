require "rails_helper"

describe Registry::Harbor do
  let(:json_headers) { { "Content-Type" => "application/json" } }

  before do
    Registry::Harbor.instance_variable_set(:@available, nil)
  end

  describe ".available?" do
    context "when the health endpoint responds with 200" do
      before do
        stub_request(:get, "http://localhost:5000/api/v2.0/health")
          .to_return(status: 200, headers: json_headers, body: { status: "healthy" }.to_json)
      end

      it "is detected as a harbor registry" do
        expect(described_class.available?).to be true
      end
    end

    context "when the health endpoint responds with 404" do
      before do
        stub_request(:get, "http://localhost:5000/api/v2.0/health").to_return(status: 404)
      end

      it "is not detected as a harbor registry" do
        expect(described_class.available?).to be false
      end
    end

    context "when the health endpoint is unreachable" do
      before do
        stub_request(:get, "http://localhost:5000/api/v2.0/health").to_raise(Faraday::ConnectionFailed)
      end

      it "is not detected as a harbor registry" do
        expect(described_class.available?).to be false
      end
    end
  end

  describe ".list_repositories" do
    let(:repositories) do
      [
        { "name" => "library/busybox", "artifact_count" => 95, "pull_count" => 12, "update_time" => "2026-09-25T06:26:25.554Z" },
        { "name" => "satellite/group/state", "artifact_count" => 1, "pull_count" => 3, "update_time" => "2026-09-24T10:00:00.000Z" }
      ]
    end

    before do
      stub_request(:get, "http://localhost:5000/api/v2.0/repositories")
        .with(query: { "page" => "1", "page_size" => "100", "sort" => "-update_time" })
        .to_return(
          status:  200,
          headers: json_headers.merge("Link" => '</api/v2.0/repositories?page=2&page_size=100&sort=-update_time>; rel="next"'),
          body:    repositories.to_json
        )
    end

    it "returns a collection of repositories including harbor metadata" do
      list = described_class.list_repositories

      expect(list).to be_instance_of Collection
      expect(list.more?).to be true
      expect(list.next_query).to eq(page: 2)
      expect(list.first).to be_instance_of Repository
      expect(list.first.name).to eq "library/busybox"
      expect(list.first.artifact_count).to eq 95
      expect(list.first.pull_count).to eq 12
      expect(list.first.update_time).to be_present
    end

    it "keeps nested repository names intact" do
      expect(described_class.list_repositories.last.name).to eq "satellite/group/state"
    end
  end

  describe ".find_repository" do
    let(:artifacts) do
      [
        {
          "digest"    => "sha256:abc",
          "push_time" => "2026-09-14T01:55:47.968Z",
          "tags"      => [ { "name" => "latest", "push_time" => "2026-09-14T01:55:48.336Z" } ]
        },
        {
          "digest"    => "sha256:def",
          "push_time" => "2026-09-01T00:00:00.000Z",
          "tags"      => [ { "name" => "v1" }, { "name" => "stable" } ]
        },
        {
          "digest"    => "sha256:ghi",
          "push_time" => "2026-09-10T00:00:00.000Z",
          "tags"      => nil
        }
      ]
    end

    before do
      stub_request(:get, "http://localhost:5000/api/v2.0/projects/library/repositories/busybox/artifacts")
        .with(query: { "page" => "1", "page_size" => "100", "with_tag" => "true", "sort" => "-push_time" })
        .to_return(status: 200, headers: json_headers, body: artifacts.to_json)
    end

    it "returns the repository with all tagged artifacts and their push times" do
      repo = described_class.find_repository("library/busybox")

      expect(repo.name).to eq "library/busybox"
      expect(repo.tags.map(&:name)).to eq %w[latest v1 stable]
      expect(repo.tags.first.push_time).to be_present
    end

    context "when the registry paginates the artifacts" do
      let(:first_page) do
        [
          {
            "digest"    => "sha256:abc",
            "push_time" => "2026-09-14T01:55:47.968Z",
            "tags"      => [ { "name" => "latest" } ]
          }
        ]
      end

      let(:second_page) do
        [
          {
            "digest"    => "sha256:xyz",
            "push_time" => "2026-09-13T00:00:00.000Z",
            "tags"      => [ { "name" => "older" } ]
          }
        ]
      end

      before do
        stub_request(:get, "http://localhost:5000/api/v2.0/projects/library/repositories/busybox/artifacts")
          .with(query: { "page" => "1", "page_size" => "100", "with_tag" => "true", "sort" => "-push_time" })
          .to_return(
            status:  200,
            headers: json_headers.merge("Link" => '</api/v2.0/projects/library/repositories/busybox/artifacts?page=2&page_size=100&sort=-push_time>; rel="next"'),
            body:    first_page.to_json
          )

        stub_request(:get, "http://localhost:5000/api/v2.0/projects/library/repositories/busybox/artifacts")
          .with(query: { "page" => "2", "page_size" => "100", "with_tag" => "true", "sort" => "-push_time" })
          .to_return(status: 200, headers: json_headers, body: second_page.to_json)
      end

      it "collects tags across all pages" do
        repo = described_class.find_repository("library/busybox")

        expect(repo.tags.map(&:name)).to eq %w[latest older]
      end
    end

    context "for an unknown repository" do
      before do
        stub_request(:get, "http://localhost:5000/api/v2.0/projects/unknown/repositories/one/artifacts")
          .with(query: hash_including("page" => "1"))
          .to_return(status: 404, headers: json_headers, body: { errors: [] }.to_json)
      end

      it "returns the repository without tags" do
        repo = described_class.find_repository("unknown/one")

        expect(repo.name).to eq "unknown/one"
        expect(repo.tags).to eq []
      end
    end

    context "for a nested repository name" do
      before do
        stub_request(:get, "http://localhost:5000/api/v2.0/projects/project/repositories/group/name/artifacts")
          .with(query: hash_including("page" => "1"))
          .to_return(status: 200, headers: json_headers, body: [].to_json)
      end

      it "only uses the first segment as project" do
        repo = described_class.find_repository("project/group/name")

        expect(repo.name).to eq "project/group/name"
        expect(repo.tags).to eq []
      end
    end
  end
end
