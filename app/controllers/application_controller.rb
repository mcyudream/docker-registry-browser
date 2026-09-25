class ApplicationController < ActionController::Base
  rescue_from Faraday::ResourceNotFound, with: :not_found
  rescue_from Faraday::ClientError, with: :client_error

  before_action :set_current_auth

  private

  def set_current_auth
    Current.http_basic_auth = ActionController::HttpAuthentication::Basic.user_name_and_password(request)
    Current.http_token_auth = session[:registry_auth_token]
  end

  def not_found
    render file: "#{Rails.root}/public/404.html", layout: false, status: 404
  end

  def client_error(error)
    raise error unless error.response && error.response[:status] == 401

    case details = error.response.dig(:headers, "www-authenticate")
    when /basic/i
      basic_authentication
    when /bearer/i
      token_authentication(details)
    else
      # Some registries (e.g. the native Harbor API) respond with a plain 401
      # and no WWW-Authenticate header. Ask the browser for basic credentials
      # as long as none have been tried yet.
      if Current.http_basic_auth.blank? && Rails.configuration.x.basic_auth_user.blank?
        request_http_basic_authentication
      else
        render "errors/invalid_credentials"
      end
    end
  end

  def basic_authentication
    request_http_basic_authentication
  end

  def token_authentication(details)
    if token_authentication_credentials.present?
      obtain_authentication_token(details)
    elsif anonymous_token_allowed?
      # Harbor issues tokens without credentials for public projects.
      obtain_authentication_token(details, nil, fallback_to_basic: true)
    else
      request_http_basic_authentication
    end
  end

  def token_authentication_credentials
    credentials = [
      Rails.configuration.x.token_auth_user,
      Rails.configuration.x.token_auth_password
    ]

    credentials.compact.presence || Current.http_basic_auth.presence
  end

  def anonymous_token_allowed?
    Rails.configuration.x.registry_type.in? %w[auto harbor]
  end

  def obtain_authentication_token(details, credentials = token_authentication_credentials, fallback_to_basic: false)
    auth_params = parse_auth_challenge(details)

    # Anonymous attempts are not counted: they happen once per request and a
    # failure falls back to asking the browser for credentials instead of
    # being retried.
    return if credentials.present? && auth_attempts_exceeded?(auth_params["scope"])

    session[:registry_auth_scope] = auth_params["scope"]
    session[:registry_auth_token] = ObtainAuthenticationToken.new(auth_params, credentials).call

    set_current_auth

    redirect_to request.fullpath if request.get?
  rescue ObtainAuthenticationToken::InvalidCredentials
    fallback_to_basic ? request_http_basic_authentication : render("errors/invalid_credentials")
  end

  def auth_attempts_exceeded?(scope)
    session[:registry_auth_attempts] = 0 if scope != session[:registry_auth_scope]
    session[:registry_auth_attempts] += 1

    return false if session[:registry_auth_attempts] <= 3

    render "errors/auth_attempts_exceeded"
    true
  end

  def parse_auth_challenge(details)
    challenge = details[/\w+ (.*)/, 1]
    Hash[challenge.scan(/(\w+)="([^"]+)"/)]
  end
end
