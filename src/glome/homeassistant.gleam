import gleam/erlang
import gleam/dynamic.{Dynamic}
import gleam/option.{Option}
import gleam/result
import gleam/io
import gleam/string
import gleam/list
import gleam/httpc
import gleam/http.{Http, Post}
import gleam/otp/process.{Receiver, Sender}
import gleam/otp/process
import nerf/websocket.{
  ConnectError, Connection, ConnectionFailed, ConnectionRefused, Frame, Text,
}
import glome/core/authentication.{AccessToken}
import glome/core/ha_client
import glome/core/json
import glome/core/loops
import glome/core/error.{
  CallServiceError, DeserializationError, GlomeError, LoopNil, WebsocketConnectionError,
}
import glome/homeassistant/state.{State}
import glome/homeassistant/state_change_event.{StateChangeEvent}
import glome/homeassistant/entity_id.{EntityId}
import glome/homeassistant/domain.{Domain}
import glome/homeassistant/environment.{Configuration}
import glome/homeassistant/service

pub opaque type HomeAssistant {
  HomeAssistant(handlers: StateChangeHandlers, config: Configuration)
}

// PUBLIC API
pub type StateChangeHandler =
  fn(StateChangeEvent, HomeAssistant) -> Result(Nil, GlomeError)

pub type StateChangeFilter =
  fn(StateChangeEvent, HomeAssistant) -> Bool

pub type StateChangeHandlersEntry {
  StateChangeHandlersEntry(
    entity_id: EntityId,
    handler: StateChangeHandler,
    filter: StateChangeFilter,
  )
}

pub type StateChangeHandlers =
  List(StateChangeHandlersEntry)

pub fn connect(
  config: Configuration,
  conn_handler: fn(HomeAssistant) -> HomeAssistant,
) -> Result(Nil, GlomeError) {

  let ha_api_path = case config.host {
    "supervisor" -> "/core/websocket"
    _ -> "/api/websocket"
  }
  let #(sender, receiver) = process.new_channel()

  process.start(fn() {
    assert Ok(connection) =
      websocket.connect(config.host, ha_api_path, config.port, [])
      |> error.map_connection_error

    assert Ok(_) = authentication.authenticate(connection, config.access_token)

    assert Ok(_) = start_state_loop(connection, sender)
  })

  let home_assistant = HomeAssistant(handlers: list.new(), config: config)

  let handlers: StateChangeHandlers = conn_handler(home_assistant).handlers

  loops.start_state_change_event_receiver(fn() {
    let state_changed_event: StateChangeEvent =
      process.receive_forever(receiver)

    list.filter(
      handlers,
      fn(entry: StateChangeHandlersEntry) {
        entry.entity_id.domain == state_changed_event.entity_id.domain && {
          entry.entity_id.object_id == state_changed_event.entity_id.object_id || entry.entity_id.object_id == "*"
        }
      },
    )
    |> list.filter(fn(entry: StateChangeHandlersEntry) {
      entry.filter(state_changed_event, home_assistant)
    })
    |> list.map(fn(entry: StateChangeHandlersEntry) {
      process.start(fn() {
        let result = entry.handler(state_changed_event, home_assistant)
        case result {
          Ok(Nil) -> Nil
          Error(error) -> {
            io.debug(error)
            Nil
          }
        }
      })
    })
    Ok(Nil)
  })
  Ok(Nil)
}

pub fn add_handler(
  to home_assistant: HomeAssistant,
  for entity_id: EntityId,
  handler handler: StateChangeHandler,
) -> HomeAssistant {
  let handlers =
    do_add_handler_with_filter(
      home_assistant.handlers,
      entity_id,
      handler,
      fn(_, _) { True },
    )
  HomeAssistant(..home_assistant, handlers: handlers)
}

pub fn add_constrained_handler(
  to home_assistant: HomeAssistant,
  for entity_id: EntityId,
  handler handler: StateChangeHandler,
  constraint filter: StateChangeFilter,
) -> HomeAssistant {
  let handlers =
    do_add_handler_with_filter(
      home_assistant.handlers,
      entity_id,
      handler,
      filter,
    )
  HomeAssistant(..home_assistant, handlers: handlers)
}

pub fn call_service(
  home_assistant: HomeAssistant,
  domain: Domain,
  service: String,
  service_data: Option(String),
) -> Result(String, GlomeError) {
  service.call(home_assistant.config, domain, service, service_data)
}

pub fn get_state(
  from home_assistant: HomeAssistant,
  of entity_id: EntityId,
) -> Result(State, GlomeError) {
  state.get(home_assistant.config, entity_id)
}

// PRIVATE API
fn do_add_handler_with_filter(
  in handlers: StateChangeHandlers,
  for entity_id: EntityId,
  handler handler: StateChangeHandler,
  predicate filter: StateChangeFilter,
) -> StateChangeHandlers {
  list.append(handlers, [StateChangeHandlersEntry(entity_id, handler, filter)])
}

fn start_state_loop(
  connection: Connection,
  sender: Sender(StateChangeEvent),
) -> Result(Nil, GlomeError) {
  let subscribe_state_change_events =
    json.encode([
      json.json_element("id", "1"),
      json.json_element("type", "subscribe_events"),
      json.json_element("event_type", "state_changed"),
    ])
  websocket.send(connection, subscribe_state_change_events)
  loops.start_state_change_event_publisher(fn() {
    case websocket.receive(connection, 500) {
      Ok(Text(message)) -> publish_state_change_event(sender, message)
      Error(nil) -> Error(LoopNil)
    }
  })
  Ok(Nil)
}

fn publish_state_change_event(
  sender: Sender(StateChangeEvent),
  message: String,
) -> Result(Nil, GlomeError) {
  try state_change_event = state_change_event.from_json(message)
  process.send(sender, state_change_event)
  Ok(Nil)
}
