import gleam/result
import nerf/websocket.{Connection, Text}
import glome/core/error.{AuthenticationError, GlomeError}
import glome/core/serde
import gleam/json.{object, string}

pub type AccessToken {
  AccessToken(value: String)
}

pub fn authenticate(
  connection: Connection,
  access_token: AccessToken,
) -> Result(String, GlomeError) {
  try _ = authentication_phase_started(connection)
  let auth_message =
    object([
      #("type", string("auth")),
      #("access_token", string(access_token.value)),
    ])
    |> json.to_string
  websocket.send(connection, auth_message)

  try Text(auth_response) =
    websocket.receive(connection, 500)
    |> result.map_error(fn(_) {
      AuthenticationError(
        "authentication failed! Auth result message not received!",
      )
    })

  try type_field =
    serde.string_field(auth_response, "type")
    |> result.map_error(fn(_) {
      AuthenticationError(
        "authentication failed! Auth result message has no field [ type ]!",
      )
    })

  case type_field {
    "auth_ok" -> Ok("Authenticated connection established")
    "auth_invalid" -> Error(AuthenticationError("Invalid authentication"))
  }
}

fn authentication_phase_started(
  connection: Connection,
) -> Result(String, GlomeError) {
  try Text(initial_message) =
    websocket.receive(connection, 500)
    |> result.map_error(fn(_) {
      AuthenticationError(
        "could not start auth phase! Auth message not received!",
      )
    })

  try auth_required =
    serde.string_field(initial_message, "type")
    |> result.map_error(fn(_) {
      AuthenticationError(
        "could not start auth phase! Auth message has no field [ type ]!",
      )
    })

  case auth_required {
    "auth_required" -> Ok(auth_required)
    _ ->
      Error(AuthenticationError(
        "Something went wrong. Authentication phase not started!",
      ))
  }
}
