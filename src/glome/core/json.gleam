import gleam/dynamic.{DecodeError, Dynamic, dynamic, string}
import gleam/result
import gleam/string
import gleam/list
import gleam/io
import glome/core/error.{EntityIdFormatError, GlomeError}

pub external fn encode(anything) -> String =
  "jsone" "encode"

pub external fn decode(String) -> Dynamic =
  "jsone" "decode"

pub fn json_element(key: String, value: a) -> #(String, a) {
  #(key, value)
}

pub fn string_field(
  data: String,
  field_name: String,
) -> Result(String, GlomeError) {
  decode(data)
  |> dynamic.from
  |> dynamic.field(field_name, string)
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
      |> result.then(fn(dyn) { get_field_by_path(dyn, string.join(xs, ".")) })
  }
}

pub fn get_field_as_string(value: Dynamic) -> Result(String, GlomeError) {
  dynamic.string(value)
  |> error.map_decode_errors
}
