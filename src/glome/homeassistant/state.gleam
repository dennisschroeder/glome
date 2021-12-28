import gleam/dynamic.{Dynamic}
import gleam/result
import glome/core/error.{GlomeError}
import glome/core/json
import glome/homeassistant/domain.{BinarySensor, Domain, InputBoolean, Light}

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

pub fn from_dynamic_by_domain(
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
