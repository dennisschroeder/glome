import gleam/string
import gleam/dynamic.{DecodeError}
import gleam/result
import gleam/int
import nerf/websocket.{ConnectError, ConnectionFailed, ConnectionRefused}

pub type GlomeError {
  WebsocketConnectionError(reason: String)
  JsonDecodeError(reason: String)
  AuthenticationError(reason: String)
  DeserializationError(cause: GlomeError, reason: String)
  EntityIdFormatError(reason: String)
  LoopNil
}

pub fn stringify_decode_error(error: DecodeError) {
  string.concat(["expected: ", error.expected, "got instead: ", error.found])
}

pub fn json_decode_error(reason: String) -> GlomeError {
  JsonDecodeError(string.concat([
    "could not decode json due to: [ ",
    reason,
    " ]",
  ]))
}

pub fn map_decode_error(error: Result(a, DecodeError)) {
  result.map_error(
    error,
    fn(decode_error: DecodeError) {
      stringify_decode_error(decode_error)
      |> json_decode_error
    },
  )
}

pub fn map_connection_error(
  error: Result(a, ConnectError),
) -> Result(a, GlomeError) {
  result.map_error(
    error,
    fn(conn_error: ConnectError) {
      case conn_error {
        ConnectionRefused(status, headers) ->
          string.concat([
            "connection from homeassistant refused,\n",
            "server responded with status [ ",
            int.to_string(status),
            " ]",
          ])
          |> WebsocketConnectionError

        ConnectionFailed(reason) ->
          string.concat([
            "connection to homeassistant failed,\n", "due to: [ ", "unknown connection error",
            " ]",
          ])
          |> WebsocketConnectionError
      }
    },
  )
}
