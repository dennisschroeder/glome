import gleam/string
import gleam/result
import gleam/dynamic.{DecodeError, Dynamic, string}
import glome/homeassistant/domain.{Domain}

pub type EntityId {
  EntityId(domain: Domain, object_id: String)
}

pub fn decoder(data: Dynamic) -> Result(EntityId, List(DecodeError)) {
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

fn map_to_entity_id(entity_id_parts: #(String, String)) -> EntityId {
  EntityId(domain.from_string(entity_id_parts.0), entity_id_parts.1)
}
