require "cgi"

module Registry
  # Backend for the native Harbor REST API v2.0 (https://goharbor.io).
  #
  # Harbor does not expose the docker catalog endpoint ("/v2/_catalog") to
  # anonymous users, so public repositories are listed through the Harbor API
  # instead. Artifact listings additionally carry push times, which enables
  # the repositories and tags to be sorted by push date.
  module Harbor
    extend Registry::Connection

    ARTIFACT_PAGE_SIZE = 100
    MAX_ARTIFACT_PAGES = 100

    class << self
      def available?
        return @available unless @available.nil?

        @available = probe_health == 200
      rescue Faraday::Error
        @available = false
      end

      def client
        Faraday.new(url: Rails.configuration.x.registry_url, ssl: ssl_options) do |f|
          if Rails.configuration.x.basic_auth_user && Rails.configuration.x.basic_auth_password
            f.request :authorization, :basic,
              Rails.configuration.x.basic_auth_user,
              Rails.configuration.x.basic_auth_password
          elsif (auth = Current.http_basic_auth).present?
            f.request :authorization, :basic, *auth
          end
          f.response :follow_redirects, limit: 5
          f.response :json, content_type: /json|prettyjws/
          f.response :logger, Rails.configuration.logger, Rails.configuration.x.registry_log_options
          f.response :raise_error
          f.adapter Faraday.default_adapter
        end
      end

      def list_repositories(page: nil, last: nil)
        page_number = [ page.to_i, 1 ].max

        response = client.get "/api/v2.0/repositories", {
          page:      page_number,
          page_size: Rails.configuration.x.catalog_page_size,
          sort:      "-update_time"
        }

        entries = Array.wrap(response.body).map do |item|
          Repository.new(
            name:           item["name"],
            artifact_count: item["artifact_count"],
            pull_count:     item["pull_count"],
            update_time:    parse_time(item["update_time"])
          )
        end

        Collection.new entries: entries, more: next_page?(response), next_query: { page: page_number + 1 }
      end

      def find_repository(name)
        project, _, repository_name = name.partition("/")

        tags = []
        page = 1

        loop do
          response = client.get "/api/v2.0/projects/#{CGI.escape(project)}/repositories/#{repository_name}/artifacts", {
            page:      page,
            page_size: ARTIFACT_PAGE_SIZE,
            with_tag:  true,
            sort:      "-push_time"
          }

          artifacts = Array.wrap(response.body)

          artifacts.each do |artifact|
            Array.wrap(artifact["tags"]).each do |tag|
              tags << TagSummary.new(
                name:      tag["name"],
                push_time: parse_time(tag["push_time"] || artifact["push_time"])
              )
            end
          end

          page += 1
          break if artifacts.empty? || !next_page?(response) || page > MAX_ARTIFACT_PAGES
        end

        Repository.new(name: name, tags: tags)
      rescue Faraday::ResourceNotFound
        Repository.new(name: name, tags: [])
      end

      private

      def next_page?(response)
        response.headers["Link"].to_s.include?('rel="next"')
      end

      def parse_time(value)
        Time.zone.parse(value) if value.present?
      end

      def probe_health
        Faraday.new(url: Rails.configuration.x.registry_url, ssl: ssl_options) do |f|
          f.options.timeout     = 5
          f.options.open_timeout = 5
          f.adapter Faraday.default_adapter
        end.get("/api/v2.0/health").status
      end
    end
  end
end
