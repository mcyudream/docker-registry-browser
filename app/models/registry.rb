# Selects the backend used to talk to the registry.
#
# Configured via the REGISTRY_TYPE environment variable:
#
# * "registry" (default): plain Docker Registry HTTP API V2.
# * "harbor":     native Harbor API (https://goharbor.io), which is required
#                 because Harbor does not expose the docker catalog endpoint to
#                 anonymous users and carries additional metadata like push times.
# * "auto":       probe the registry once and use the Harbor backend when it
#                 answers on /api/v2.0/health, fall back to the plain registry.
module Registry
  def self.backend
    case Rails.configuration.x.registry_type
    when "harbor"
      Registry::Harbor
    when "registry"
      Registry::V2
    else
      Registry::Harbor.available? ? Registry::Harbor : Registry::V2
    end
  end
end
