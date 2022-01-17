import gleam/result
import gleam/option.{None, Option, Some}
import gleam/io
import gleam/string
import gleam/httpc
import gleam/http.{Get, Http, Method, Post}
import glome/core/authentication.{AccessToken}
import glome/core/error.{
  BadRequest, CallServiceError, GlomeError, NotAllowedHttpMethod, NotFound,
}

pub fn send_ha_rest_api_request(
  host: String,
  port: Int,
  access_token: AccessToken,
  method: Method,
  path_elements: List(String),
  body: Option(String),
) -> Result(String, GlomeError) {
  try method = ensure_post_or_get(method)
  let req =
    http.default_req()
    |> http.set_scheme(Http)
    |> http.set_host(host)
    |> http.set_port(port)
    |> http.prepend_req_header("accept", "application/json")
    |> http.prepend_req_header(
      "Authorization",
      string.append("Bearer ", access_token.value),
    )
    |> http.set_method(method)
    |> http.set_path(string.concat(["/api", ..path_elements]))

  let req = case body {
    Some(data) -> http.set_req_body(req, data)
    None -> req
  }

  try resp =
    httpc.send(req)
    |> result.map_error(fn(error) {
      io.debug(error)
      CallServiceError("Error calling service")
    })

  case resp.status {
    200 -> Ok(resp.body)
    400 -> Error(BadRequest(resp.body))
    404 -> Error(NotFound(resp.body))
  }
}

fn ensure_post_or_get(method: Method) {
  case method {
    Post | Get -> Ok(method)
    _ -> Error(NotAllowedHttpMethod)
  }
}
