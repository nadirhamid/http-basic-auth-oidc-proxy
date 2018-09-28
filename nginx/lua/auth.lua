local opts = {
    redirect_uri_path = os.getenv("OID_REDIRECT_PATH") or "/redirect_uri",
    discovery = os.getenv("OID_DISCOVERY"),
    client_id = os.getenv("OID_CLIENT_ID"),
    client_secret = os.getenv("OID_CLIENT_SECRET"),
    token_endpoint_auth_method = os.getenv("OIDC_AUTH_METHOD") or "client_secret_basic",
    renew_access_token_on_expiry = os.getenv("OIDC_RENEW_ACCESS_TOKEN_ON_EXPIERY") ~= "false",
    scope = os.getenv("OIDC_AUTH_SCOPE") or "openid",
    iat_slack = 600,
}

local opts_basic_auth = {
    basic_auth_username = os.getenv("BASIC_AUTH_USERNAME"),
    basic_auth_password = os.getenv("BASIC_AUTH_PASSWORD"),
}

local log_user_claim = os.getenv("LOG_USER_CLAIM")

-- Try to authenticate with Basic Auth
local res = require("basic_auth").authenticate(opts_basic_auth)
if res then
    return
end

-- Try OIDC auth as fallback
-- call authenticate for OpenID Connect user authentication
local res, err, _target, session = require("resty.openidc").authenticate(opts)

ngx.log(ngx.INFO, tostring(res))
ngx.log(ngx.INFO, tostring(err))

ngx.log(ngx.INFO,
  "session.present=", session.present,
  ", session.data.id_token=", session.data.id_token ~= nil,
  ", session.data.authenticated=", session.data.authenticated,
  ", opts.force_reauthorize=", opts.force_reauthorize,
  ", opts.renew_access_token_on_expiry=", opts.renew_access_token_on_expiry,
  ", try_to_renew=", try_to_renew,
  ", token_expired=", token_expired
)

if err then
    ngx.status = 500
    ngx.header.content_type = 'text/html';

    ngx.say("There was an error while logging in: " .. err)
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
end

ngx.log(ngx.INFO, "Authentication successful, setting Auth header...")
ngx.req.set_header("Authorization", "Bearer " .. session.data.enc_id_token)

if log_user_claim then
    ngx.req.set_header("X-User", res.id_token[log_user_claim])
end
