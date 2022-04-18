import gleam/string
import gleam/dynamic
import gleam/result
import glome/core/json
import glome/core/error.{DeserializationError, GlomeError}
import glome/homeassistant/entity_id.{EntityId}
import glome/homeassistant/state.{State}

pub type StateChangeEvent {
  StateChangeEvent(entity_id: EntityId, old_state: State, new_state: State)
}

pub fn from_json(event_message: String) -> Result(StateChangeEvent, GlomeError) {
  try entity_id =
    event_message
    |> entity_id.from_state_change_event_json

  try old_state =
    event_message
    |> json.decode
    |> dynamic.from
    |> json.get_field_by_path("event.data.old_state")
    |> result.then(state.from_dynamic_by_domain(_, entity_id.domain))
    |> result.map_error(DeserializationError(_, reason: string.concat([
      "could not deserialize old_state value of [ ",
      entity_id.to_string(entity_id),
      " ]",
    ])))

  try new_state =
    event_message
    |> json.decode
    |> dynamic.from
    |> json.get_field_by_path("event.data.new_state")
    |> result.then(state.from_dynamic_by_domain(_, entity_id.domain))
    |> result.map_error(DeserializationError(_, reason: string.concat([
      "could not deserialize new_state value of [ ",
      entity_id.to_string(entity_id),
      " ]",
    ])))

  StateChangeEvent(
    entity_id: entity_id,
    old_state: old_state,
    new_state: new_state,
  )
  |> Ok
}
