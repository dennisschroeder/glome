import gleam/option.{Option}
import gleam/http.{Post}
import glome/homeassistant/domain.{Domain}
import glome/homeassistant/environment.{Configuration}
import glome/core/error.{GlomeError}
import glome/core/ha_client

pub fn call(
  config: Configuration,
  domain: Domain,
  service: String,
  service_data: Option(String),
) -> Result(String, GlomeError) {
  ha_client.send_ha_rest_api_request(
    config.host,
    config.port,
    config.access_token,
    Post,
    ["/services", "/", domain.to_string(domain), "/", service],
    service_data,
  )
}
