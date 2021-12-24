import gleeunit/should
import json.{extract_entity_id_string_parts, get_field_by_path, string_field}
import gleam/dynamic.{DecodeError, Dynamic}
import gleam/io
import gleam/result
import gleam/list
import gleam/string
import json
import error.{EntityIdFormatError}

pub fn string_field_happy_path_test() {
  "{\"foo\": \"bar\"}"
  |> json.string_field("foo")
  |> should.equal(Ok("bar"))
}

pub fn string_field_unknown_field_error_test() {
  "{\"foo\": \"bar\"}"
  |> json.string_field("unknown")
  |> should.be_error
}

pub fn string_field_not_string_error_test() {
  "{\"foo\": 73}"
  |> json.string_field("foo")
  |> should.be_error
}

pub fn extract_entity_id_parts_happy_path_test() {
  "light.main"
  |> json.extract_entity_id_string_parts
  |> should.equal(Ok(#("light", "main")))
}

pub fn extract_entity_id_parts_no_dot_path_test() {
  "lightmain"
  |> json.extract_entity_id_string_parts
  |> should.be_error
}

pub fn extract_entity_id_parts_more_than_two_dots_path_test() {
  "light.main.kitchen"
  |> json.extract_entity_id_string_parts
  |> should.be_error
}

pub fn get_field_traversing_happy_path_test() {
  "{\"event\": { \"data\": {\"entity_id\": \"domain.object_id\"}}}"
  |> json.decode
  |> dynamic.from
  |> get_field_by_path("event.data.entity_id")
  |> result.then(json.get_field_as_string)
  |> should.equal(Ok("domain.object_id"))
}
