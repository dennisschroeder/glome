import gleam/string
import gleam/result
import gleam/dynamic.{DecodeError, Dynamic, dynamic, string}
import gleam/json
import glome/core/error.{DeserializationError, EntityIdFormatError, GlomeError}
import glome/core/serde
import glome/homeassistant/domain.{Domain}

pub type EntityId {
  EntityId(domain: Domain, object_id: String)
}

pub fn from_state_change_event_json(
  json: String,
) -> Result(EntityId, GlomeError) {
  json
  |> json.decode(dynamic)
  |> dynamic.from
  |> serde.get_field_by_path("event.data.entity_id")
  |> result.then(serde.get_field_as_string)
  |> result.then(from_string)
  |> result.map_error(DeserializationError(
    _,
    reason: "could not create EntityId(Domain,String) from state change event",
  ))
}

pub fn entiy_id_decoder(data: Dynamic) -> Result(EntityId, List(DecodeError)) {
  data
  |> string
  |> result.then(decode_entity_id)
  |> result.map(map_to_entity_id)
}

fn decode_entity_id(
  entity_id: String,
) -> Result(#(String, String), List(DecodeError)) {
  case string.split(entity_id, ".") {
    [_] ->
      Error(DecodeError(
        expected: "domain.object_id",
        found: entity_id,
        path: [],
      ))
    [domain, object_id] -> Ok(#(domain, object_id))
    [_, _, ..] ->
      Error(DecodeError(
        expected: "domain.object_id",
        found: entity_id,
        path: [],
      ))
  }
  |> result.map_error(fn(error) { [error] })
}

pub fn to_string(entity_id: EntityId) -> String {
  string.concat([domain.to_string(entity_id.domain), ".", entity_id.object_id])
}

fn from_string(entity_id: String) -> Result(EntityId, GlomeError) {
  entity_id
  |> extract_entity_id_string_parts
  |> result.map(map_to_entity_id)
}

fn extract_entity_id_string_parts(
  entity_id: String,
) -> Result(#(String, String), GlomeError) {
  case string.split(entity_id, ".") {
    [_] ->
      Error(EntityIdFormatError(string.concat([
        "malformed entity_id format. Missing object_id \n. Given format is [ ",
        entity_id,
        " ]. Correct format would be [ ",
        "domain.object_id ]",
      ])))
    [domain, object_id] -> Ok(#(domain, object_id))
    [_, _, ..] ->
      Error(EntityIdFormatError(string.concat([
        "malformed entity_id format. Entity_id shall contain exactly 2 parts not more \n. Given format is [ ",
        entity_id,
        " ]. Correct format would be [ ",
        "domain.object_id ]",
      ])))
  }
}

fn map_to_entity_id(entity_id_parts: #(String, String)) -> EntityId {
  EntityId(domain.from_string(entity_id_parts.0), entity_id_parts.1)
}
