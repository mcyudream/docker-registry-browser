module Registry
  # Backend for the Docker Registry HTTP API V2
  # (https://distribution.github.io/distribution/spec/api/).
  module V2
    extend Registry::Connection

    class << self
      def client
        Faraday.new(url: Rails.configuration.x.registry_url, ssl: ssl_options) do |f|
          if Rails.configuration.x.basic_auth_user && Rails.configuration.x.basic_auth_password
            f.request :authorization, :basic,
              Rails.configuration.x.basic_auth_user,
              Rails.configuration.x.basic_auth_password
          elsif (token = Current.http_token_auth).present?
            f.request :authorization, :bearer, token
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
        response = client.get "/v2/_catalog", { n: Rails.configuration.x.catalog_page_size, last: last }.compact
        entries  = Array.wrap(response.body["repositories"]).map { |name| Repository.new(name: name) }

        Collection.new entries: entries, more: response.headers.has_key?("Link"), next_query: { last: entries.last&.name }
      end

      def find_repository(name)
        tags = begin
          response = client.get "/v2/#{name}/tags/list"
          Array.wrap(response.body["tags"]).map { |tag| TagSummary.new(name: tag) }
        rescue Faraday::ResourceNotFound
          []
        end

        Repository.new(name: name, tags: tags)
      end
    end
  end
end
