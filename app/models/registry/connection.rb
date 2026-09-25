module Registry
  # Shared TLS settings for outgoing registry connections.
  module Connection
    def ssl_options
      {
        verify:  Rails.configuration.x.no_ssl_verification.!,
        ca_file: Rails.configuration.x.ca_file
      }.compact
    end
  end
end
