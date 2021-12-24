import gleam/erlang
import gleam/dynamic.{Dynamic}
import nerf/websocket.{
  ConnectError, Connection, ConnectionFailed, ConnectionRefused, Frame, Text,
}
import gleam/io
import gleam/string
import json
import gleam/result
import gleam/otp/process.{Receiver, Sender}
import gleam/otp/process
import loops
import gleam/list
import error.{
  AuthenticationError, DeserializationError, GlomeError, LoopNil, WebsocketConnectionError,
}

// PUBLIC API
pub type AccessToken {
  AccessToken(value: String)
}

pub type Configuration {
  Configuration(host: String, port: Int, access_token: AccessToken)
}

pub type Domain {
  AlarmControlPanel
  BinarySensor
  Button
  Calendar
  Camera
  Climate
  Cover
  DeviceTracker
  Fan
  GeoLocation
  Group
  Humidifier
  ImageProcessing
  InputBoolean
  Light
  Lock
  MediaPlayer
  Notifiy
  Number
  Person
  Remote
  Scene
  Select
  Sensor
  STT
  Sun
  Switch
  TTS
  Vacuum
  WaterHeater
  Weather
  Zone
  Domain(name: String)
}

pub type EntityId {
  EntityId(domain: Domain, object_id: String)
}

pub type StateValue {
  On
  Off
  Low
  Normal
  Open
  Closed
  Charging
  NotCharging
  Cold
  Connected
  Disconnected
  GasDetected
  NoGas
  Hot
  LightDetected
  NoLight
  Unlocked
  Locked
  MoistureDetected
  NoMoisture
  MotionDetected
  Moving
  NotMoving
  NoMotion
  Occupied
  NotOccupied
  PluggedIn
  Unplugged
  PowerDetected
  NoPower
  Home
  Away
  NotHome
  ProblemDetected
  NoProblem
  Running
  NotRunning
  Unsafe
  Safe
  SmokeDetected
  NoSmoke
  SoundDetected
  NoSound
  TamperingDetected
  NoTampering
  UpdateAvailable
  UpToDate
  VibrationDetected
  NoVibration
  Heat
  Unavailable
  StateValue(value: String)
}

pub type Attributes {
  Attributes(Dynamic)
}

pub type State {
  State(value: StateValue, attributes: Attributes)
}

pub type StateChangeEvent {
  StateChangeEvent(entity_id: EntityId, old_state: State, new_state: State)
}

pub type StateChangeHandler =
  fn(StateChangeEvent) -> Result(Nil, GlomeError)

pub type StateChangeFilter =
  fn(StateChangeEvent) -> Bool

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
  conn_handler: fn(StateChangeHandlers) -> StateChangeHandlers,
) -> Result(Nil, GlomeError) {
  let ha_api_path = "/api/websocket"
  let #(sender, receiver) = process.new_channel()

  process.start(fn() {
    try connection =
      websocket.connect(config.host, ha_api_path, config.port, [])
      |> error.map_connection_error

    try _ = authenticate(connection, config.access_token)

    start_state_loop(connection, sender)
  })

  let handlers: StateChangeHandlers = conn_handler(list.new())

  loops.start_state_change_event_receiver(fn() {
    let state_changed_event: StateChangeEvent =
      process.receive_forever(receiver)

    list.filter(
      handlers,
      fn(entry: StateChangeHandlersEntry) {
        entry.entity_id.domain == state_changed_event.entity_id.domain && {
          entry.entity_id.object_id == state_changed_event.entity_id.object_id || entry.entity_id.object_id == "*"
        } && entry.filter(state_changed_event)
      },
    )
    |> list.map(fn(entry: StateChangeHandlersEntry) {
      entry.handler(state_changed_event)
    })
    |> list.map(fn(result: Result(Nil, GlomeError)) {
      case result {
        Ok(Nil) -> Nil
        Error(error) -> {
          io.debug(error)
          Nil
        }
      }
    })
    Ok(Nil)
  })

  Ok(Nil)
}

pub fn register_handler(
  in handlers: StateChangeHandlers,
  for entity_id: EntityId,
  handler handler: StateChangeHandler,
  predicate filter: StateChangeFilter,
) -> StateChangeHandlers {
  do_register_handler_with_filter(handlers, entity_id, handler, filter)
}

fn do_register_handler_with_filter(
  in handlers: StateChangeHandlers,
  for entity_id: EntityId,
  handler handler: StateChangeHandler,
  predicate filter: StateChangeFilter,
) -> StateChangeHandlers {
  list.append(handlers, [StateChangeHandlersEntry(entity_id, handler, filter)])
}

// PRIVATE API
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
      Ok(Text(message)) -> publish_state_change_event_message(sender, message)
      Error(nil) -> Error(LoopNil)
    }
  })
  Ok(Nil)
}

fn publish_state_change_event_message(
  sender: Sender(StateChangeEvent),
  message: String,
) -> Result(Nil, GlomeError) {
  try state_change_event = deserialize_to_state_change_event(message)
  process.send(sender, state_change_event)
  Ok(Nil)
}

fn deserialize_to_state_change_event(
  event_message: String,
) -> Result(StateChangeEvent, GlomeError) {
  try entity_id =
    event_message
    |> json.get_entity_id_string
    |> result.then(json.extract_entity_id_string_parts)
    |> result.map(map_to_entity_id)
    |> result.map_error(DeserializationError(
      _,
      reason: "could not extract entity_id string",
    ))

  try old_state =
    event_message
    |> json.decode
    |> dynamic.from
    |> json.get_field_by_path("event.data.old_state")
    |> result.then(deserialize_state(_, entity_id.domain))
    |> result.map_error(DeserializationError(
      _,
      reason: "could not deserialize old_state value",
    ))

  try new_state =
    event_message
    |> json.decode
    |> dynamic.from
    |> json.get_field_by_path("event.data.new_state")
    |> result.then(deserialize_state(_, entity_id.domain))
    |> result.map_error(DeserializationError(
      _,
      "could not deserialize new_state value",
    ))

  StateChangeEvent(
    entity_id: entity_id,
    old_state: old_state,
    new_state: new_state,
  )
  |> Ok
}

fn deserialize_state(
  state_map: Dynamic,
  domain: Domain,
) -> Result(State, GlomeError) {
  try state_value_string =
    json.get_field_by_path(state_map, "state")
    |> result.then(json.get_field_as_string)
  try attributes =
    json.get_field_by_path(state_map, "attributes")
    |> result.map(Attributes)

  case domain {
    Light -> map_to_light_state(state_value_string, attributes)
    InputBoolean -> map_to_boolean_state(state_value_string, attributes)
    BinarySensor -> map_to_binary_sensor_state(state_value_string, attributes)
    domain -> Ok(State(StateValue(state_value_string), attributes))
  }
}

fn map_to_light_state(
  state_value: String,
  attributes: Attributes,
) -> Result(State, GlomeError) {
  let mapped_state_value = case state_value {
    "on" -> On
    "off" -> Off
    "unavailable" -> Unavailable
    value -> StateValue(value)
  }
  Ok(State(mapped_state_value, attributes))
}

fn map_to_boolean_state(
  state_value: String,
  attributes: Attributes,
) -> Result(State, GlomeError) {
  let mapped_state_value = case state_value {
    "on" -> On
    "off" -> Off
    value -> StateValue(value)
  }
  Ok(State(mapped_state_value, attributes))
}

fn map_to_binary_sensor_state(
  state_value: String,
  attributes: Attributes,
) -> Result(State, GlomeError) {
  let Attributes(attributes) = attributes

  let device_class =
    json.get_field_by_path(attributes, "device_class")
    |> result.then(json.get_field_as_string)
    |> result.unwrap("unknown_device_class")
  let mapped_state_value = case state_value, device_class {
    "on", "battery" -> Low
    "on", "battery_charging" -> Charging
    "on", "cold" -> Cold
    "on", "connectivity" -> Connected
    "on", "door" -> Open
    "on", "garage_door" -> Open
    "on", "gas" -> GasDetected
    "on", "heat" -> Hot
    "on", "light" -> LightDetected
    "on", "lock" -> Unlocked
    "on", "moisture" -> MoistureDetected
    "on", "motion" -> MotionDetected
    "on", "moving" -> Moving
    "on", "occupancy" -> Occupied
    "on", "opening" -> Open
    "on", "plug" -> PluggedIn
    "on", "power" -> PluggedIn
    "on", "presence" -> Home
    "on", "problem" -> ProblemDetected
    "on", "running" -> Running
    "on", "safety" -> Unsafe
    "on", "smoke" -> SmokeDetected
    "on", "sound" -> SoundDetected
    "on", "tamper" -> TamperingDetected
    "on", "update" -> UpdateAvailable
    "on", "vibration" -> VibrationDetected
    "on", "window" -> Open

    "off", "battery" -> Normal
    "off", "battery_charging" -> NotCharging
    "off", "cold" -> Normal
    "off", "connectivity" -> Disconnected
    "off", "door" -> Closed
    "off", "garage_ door" -> Open
    "off", "garage_ gas" -> NoGas
    "off", "heat" -> Normal
    "off", "light" -> NoLight
    "off", "lock" -> Locked
    "off", "moisture" -> NoMoisture
    "off", "motion" -> NoMotion
    "off", "moving" -> NotMoving
    "off", "occupancy" -> NotOccupied
    "off", "opening" -> Closed
    "off", "plug" -> Unplugged
    "off", "presence" -> Away
    "off", "problem" -> NoProblem
    "off", "running" -> NotRunning
    "off", "safety" -> Safe
    "off", "smoke" -> NoSmoke
    "off", "sound" -> NoSound
    "off", "tamper" -> NoTampering
    "off", "update" -> UpToDate
    "off", "vibration" -> NoVibration
    "off", "window" -> Closed
    "unavailable", _ -> Unavailable
    value, _ -> StateValue(value)
  }
  Ok(State(mapped_state_value, Attributes(attributes)))
}

fn map_to_entity_id(entity_id_parts: #(String, String)) -> EntityId {
  case entity_id_parts.0 {
    "alarm_control_panel" -> EntityId(AlarmControlPanel, entity_id_parts.1)
    "binary_sensor" -> EntityId(BinarySensor, entity_id_parts.1)
    "button" -> EntityId(Button, entity_id_parts.1)
    "calendar" -> EntityId(Calendar, entity_id_parts.1)
    "camera" -> EntityId(Camera, entity_id_parts.1)
    "climate" -> EntityId(Climate, entity_id_parts.1)
    "cover" -> EntityId(Cover, entity_id_parts.1)
    "device_tracker" -> EntityId(DeviceTracker, entity_id_parts.1)
    "fan" -> EntityId(Fan, entity_id_parts.1)
    "group" -> EntityId(Group, entity_id_parts.1)
    "humidifier" -> EntityId(Humidifier, entity_id_parts.1)
    "input_boolean" -> EntityId(InputBoolean, entity_id_parts.1)
    "light" -> EntityId(Light, entity_id_parts.1)
    "lock" -> EntityId(Lock, entity_id_parts.1)
    "media_player" -> EntityId(MediaPlayer, entity_id_parts.1)
    "number" -> EntityId(Number, entity_id_parts.1)
    "person" -> EntityId(Person, entity_id_parts.1)
    "remote" -> EntityId(Remote, entity_id_parts.1)
    "select" -> EntityId(Select, entity_id_parts.1)
    "sensor" -> EntityId(Sensor, entity_id_parts.1)
    "sun" -> EntityId(Sun, entity_id_parts.1)
    "switch" -> EntityId(Switch, entity_id_parts.1)
    "vacuum" -> EntityId(Vacuum, entity_id_parts.1)
    "water_heater" -> EntityId(WaterHeater, entity_id_parts.1)
    "weather" -> EntityId(Weather, entity_id_parts.1)
    "zone" -> EntityId(Zone, entity_id_parts.1)
    domain -> EntityId(Domain(domain), entity_id_parts.1)
  }
}

fn authenticate(
  connection: Connection,
  access_token: AccessToken,
) -> Result(String, GlomeError) {
  try _ = authentication_phase_started(connection)
  let auth_message =
    json.encode([
      json.json_element("type", "auth"),
      json.json_element("access_token", access_token.value),
    ])
  websocket.send(connection, auth_message)

  try Text(auth_response) =
    websocket.receive(connection, 500)
    |> result.map_error(fn(_) {
      AuthenticationError(
        "authentication failed! Auth result message not received!",
      )
    })

  try type_field =
    json.string_field(auth_response, "type")
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
    json.string_field(initial_message, "type")
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
