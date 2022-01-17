import gleam/dynamic.{Dynamic}
import gleam/result
import gleam/option.{None}
import gleam/http.{Get}
import glome/core/error.{GlomeError}
import glome/core/json
import glome/core/ha_client
import glome/homeassistant/domain.{
  BinarySensor, Domain, InputBoolean, Light, Sensor,
}
import glome/homeassistant/entity_id.{EntityId}
import glome/homeassistant/environment.{Configuration}

pub type StateValue {
  //Sensor 
  AirQualityIndex(value: String)
  Battery(value: String)
  CarbonDioxide(value: String)
  CarbonMonoxide(value: String)
  Current(value: String)
  Date(value: String)
  Energy(value: String)
  Frequency(value: String)
  Gas(value: String)
  Humidity(value: String)
  Illuminance(value: String)
  Monetary(value: String)
  NitrogenDioxide(value: String)
  NitrogenMonoxide(value: String)
  NitrousOxide(value: String)
  Ozone(value: String)
  PM1(value: String)
  PM10(value: String)
  PM25(value: String)
  PowerFactor(value: String)
  Power(value: String)
  Pressure(value: String)
  SignalStrength(value: String)
  SulphurDioxide(value: String)
  Temperature(value: String)
  Timestamp(value: String)
  VolatileOrganicCompounds(value: String)
  Voltage(value: String)
  //BinarySensor
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

pub fn get(
  config: Configuration,
  entity_id: EntityId,
) -> Result(State, GlomeError) {
  ha_client.send_ha_rest_api_request(
    config.host,
    config.port,
    config.access_token,
    Get,
    ["/states", "/", entity_id.to_string(entity_id)],
    None,
  )
  |> result.map(json.decode)
  |> result.map(dynamic.from)
  |> result.map(fn(value) { from_dynamic_by_domain(value, entity_id.domain) })
  |> result.flatten
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
    Sensor -> map_to_sensor_state(state_value_string, attributes)
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

fn map_to_sensor_state(
  state_value: String,
  attributes: Attributes,
) -> Result(State, GlomeError) {
  let Attributes(attributes) = attributes

  let device_class =
    json.get_field_by_path(attributes, "device_class")
    |> result.then(json.get_field_as_string)
    |> result.unwrap("unknown_device_class")

  let mapped_state_value = case device_class {
    "aqi" -> AirQualityIndex(state_value)
    "battery" -> Battery(state_value)
    "carbon_dioxide" -> CarbonDioxide(state_value)
    "carbon_monoxide" -> CarbonMonoxide(state_value)
    "current" -> Current(state_value)
    "date" -> Date(state_value)
    "energy" -> Energy(state_value)
    "frequency" -> Frequency(state_value)
    "gas" -> Gas(state_value)
    "humidity" -> Humidity(state_value)
    "illuminance" -> Illuminance(state_value)
    "monetary" -> Monetary(state_value)
    "nitrogen_dioxide" -> NitrogenDioxide(state_value)
    "nitrogen_monoxide" -> NitrogenMonoxide(state_value)
    "nitrous_oxide" -> NitrousOxide(state_value)
    "ozone" -> Ozone(state_value)
    "pm1" -> PM1(state_value)
    "pm10" -> PM10(state_value)
    "pm25" -> PM25(state_value)
    "power_factor" -> PowerFactor(state_value)
    "power" -> Power(state_value)
    "pressure" -> Pressure(state_value)
    "signal_strength" -> SignalStrength(state_value)
    "sulphur_dioxide" -> SulphurDioxide(state_value)
    "temperature" -> Temperature(state_value)
    "timestamp" -> Timestamp(state_value)
    "volatile_organic_compounds" -> VolatileOrganicCompounds(state_value)
    "voltage" -> Voltage(state_value)
    _ -> StateValue(state_value)
  }

  Ok(State(mapped_state_value, Attributes(attributes)))
}
