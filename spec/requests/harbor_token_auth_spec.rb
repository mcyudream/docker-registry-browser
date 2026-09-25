require "rails_helper"

RSpec.describe "Harbor anonymous token authentication" do
  let(:json_headers) { { "Content-Type" => "application/json" } }

  let(:challenge) do
    {
      status:  401,
      headers: { "www-authenticate" => 'bearer realm="https://harbor.example.com/service/token" service="harbor-registry" scope="repository:library/busybox:pull"' }
    }
  end

  let(:manifest) do
    {
      schemaVersion: 2,
      mediaType:     "application/vnd.docker.distribution.manifest.v2+json",
      config:        { mediaType: "application/vnd.docker.container.image.v1+json", size: 703, digest: "sha256:config" },
      layers:        []
    }
  end

  let(:blob) do
    {
      architecture:  "amd64",
      os:            "linux",
      created:       "2026-01-01T00:00:00Z",
      history:       [],
      config:        { Env: [], Labels: {} }
    }
  end

  let(:token_request) do
    a_request(:get, "https://harbor.example.com/service/token")
      .with(query: hash_including("service" => "harbor-registry", "scope" => "repository:library/busybox:pull"))
  end

  before do
    allow(Rails.configuration.x).to receive(:registry_type).and_return("harbor")
    allow(Rails.configuration.x).to receive(:token_auth_user).and_return(nil)
    allow(Rails.configuration.x).to receive(:token_auth_password).and_return(nil)

    stub_request(:get, "http://localhost:5000/api/v2.0/projects/library/repositories/busybox/artifacts")
      .with(query: hash_including("with_tag" => "true"))
      .to_return(
        status:  200,
        headers: json_headers,
        body:    [ { "digest" => "sha256:abc", "tags" => [ { "name" => "latest" } ] } ].to_json
      )
  end

  context "when the registry issues a token without credentials" do
    before do
      stub_request(:get, "https://harbor.example.com/service/token")
        .with(query: hash_including("scope" => "repository:library/busybox:pull"))
        .to_return(status: 200, headers: json_headers, body: { token: "anonymous-token" }.to_json)

      stub_request(:get, "http://localhost:5000/v2/library/busybox/manifests/latest").to_return(challenge)

      stub_request(:get, "http://localhost:5000/v2/library/busybox/manifests/latest")
        .with(headers: { "Authorization" => /\Abearer anonymous-token\z/i })
        .to_return(status: 200, headers: json_headers, body: manifest.to_json)

      stub_request(:get, "http://localhost:5000/v2/library/busybox/blobs/sha256:config")
        .to_return(status: 200, headers: { "Content-Type" => "application/octet-stream" }, body: blob.to_json)
    end

    it "obtains an anonymous token without any Authorization header" do
      get "/repo/library/busybox/tag/latest"

      expect(response).to redirect_to("/repo/library/busybox/tag/latest")
      expect(token_request).to have_been_made.once
      expect(session[:registry_auth_token]).to eq "anonymous-token"
    end

    it "renders the tag on the following request" do
      get "/repo/library/busybox/tag/latest"
      get "/repo/library/busybox/tag/latest"

      expect(response).to have_http_status :ok
      expect(response.body).to include "latest"
    end
  end

  context "when the anonymous token is rejected" do
    before do
      stub_request(:get, "https://harbor.example.com/service/token")
        .with(query: hash_including("scope" => "repository:library/busybox:pull"))
        .to_return(status: 401)

      stub_request(:get, "http://localhost:5000/v2/library/busybox/manifests/latest").to_return(challenge)
    end

    it "asks the browser for credentials" do
      get "/repo/library/busybox/tag/latest"

      expect(response).to have_http_status :unauthorized
    end
  end
end
