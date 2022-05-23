import gleam/dynamic.{Dynamic, dynamic, string}
import gleam/result
import gleam/string
import glome/core/error.{GlomeError}
import gleam/json

pub fn decode_to_dynamic(json: String) -> Result(Dynamic, GlomeError) {
  json
  |> json.decode(dynamic)
  |> result.map_error(error.json_decode_to_dynamic_decode_error)
  |> error.map_decode_errors
}

pub fn string_field(
  data: String,
  field_name: String,
) -> Result(String, GlomeError) {
  json.decode(from: data, using: dynamic.field(field_name, string))
  |> result.map_error(error.json_decode_to_dynamic_decode_error)
  |> error.map_decode_errors
}

pub fn get_field_by_path(
  data: Dynamic,
  path: String,
) -> Result(Dynamic, GlomeError) {
  case string.split(path, ".") {
    [x] ->
      data
      |> dynamic.field(x, dynamic)
      |> error.map_decode_errors
    [x, ..xs] ->
      data
      |> dynamic.field(x, dynamic)
      |> error.map_decode_errors
      |> result.then(get_field_by_path(_, string.join(xs, ".")))
  }
}

pub fn get_field_as_string(value: Dynamic) -> Result(String, GlomeError) {
  dynamic.string(value)
  |> error.map_decode_errors
}
