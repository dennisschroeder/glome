import gleam/dynamic.{DecodeError, Dynamic, field, string}
import gleam/result
import gleam/option.{None}
import gleam/http.{Get}
import glome/core/error.{GlomeError}
import glome/core/serde
import glome/core/ha_client
import glome/homeassistant/domain.{
  BinarySensor, Cover, Domain, InputBoolean, Light, MediaPlayer, Sensor,
}
import glome/homeassistant/attributes.{
  AQISensor, Attributes, BatteryCharging, BatterySensor, CarbonDioxideSensor, CarbonMonoxideSensor,
  ColdSensor, ConnectivitySensor, CurrentSensor, DateSensor, DoorSensor, EnergySensor,
  FrequencySensor, GarageDoorSensor, GasSensor, HeatSensor, HumiditySensor, IlluminanceSensor,
  LightSensor, LockSensor, MoistureSensor, MonetarySensor, MotionSensor, MovingSensor,
  NitrogenDioxideSensor, NitrogenMonoxideSensor, NitrousOxideSensor, OccupancySensor,
  OpeningSensor, OzoneSensor, PM10Sensor, PM1Sensor, PM25Sensor, PlugSensor, PowerFactorSensor,
  PowerSensor, PresenceSensor, PressureSensor, ProblemSensor, RunningSensor, SafetySensor,
  SignalStrengthSensor, SmokeSensor, SoundSensor, SulphurDioxideSensor, TV, TamperSensor,
  TemperatureSensor, TimestampSensor, UnknownDeviceClass, UpdateSensor, VibrationSensor,
  VolatileOrganicCompoundsSensor, VoltageSensor, WindowSensor,
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
  // MediaPlayer
  Idle
  Playing
  Paused
  Buffering

  Unavailable
  Unknown
  StateValue(value: String)
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
  |> result.then(serde.decode_to_dynamic)
  |> result.map_error(fn(_) { [] })
  |> result.then(decode(_, entity_id.domain))
  |> error.map_decode_errors
}

pub fn decode(data: Dynamic, domain: Domain) -> Result(State, List(DecodeError)) {
  try state_value_string = field("state", string)(data)
  try attributes = field("attributes", attributes.decoder(_, domain))(data)

  case domain {
    MediaPlayer -> map_to_media_player_state(state_value_string, attributes)
    Cover -> map_to_open_closed_state(state_value_string, attributes)
    Light -> map_to_light_state(state_value_string, attributes)
    InputBoolean -> map_to_boolean_state(state_value_string, attributes)
    BinarySensor -> map_to_binary_sensor_state(state_value_string, attributes)
    Sensor -> map_to_sensor_state(state_value_string, attributes)
    _ -> State(StateValue(state_value_string), attributes)
  }
  |> Ok
}

fn map_to_media_player_state(
  state_value: String,
  attributes: Attributes,
) -> State {
  let mapped_state_value = case state_value, attributes.device_class {
    "on", TV -> On
    "off", TV -> Off
    "on", UnknownDeviceClass -> On
    "off", UnknownDeviceClass -> Off
    "idle", UnknownDeviceClass -> Idle
    "buffering", UnknownDeviceClass -> Buffering
    "playing", UnknownDeviceClass -> Playing
    "paused", UnknownDeviceClass -> Paused
    "unavailable", _ -> Unavailable
    "unknown", _ -> Unknown
    state, _ -> StateValue(state)
  }
  State(mapped_state_value, attributes)
}

fn map_to_open_closed_state(
  state_value: String,
  attributes: Attributes,
) -> State {
  let mapped_state_value = case state_value {
    "open" -> Open
    "closed" -> Closed
    "unavailable" -> Unavailable
    value -> StateValue(value)
  }

  State(mapped_state_value, attributes)
}

fn map_to_light_state(state_value: String, attributes: Attributes) -> State {
  let mapped_state_value = case state_value {
    "on" -> On
    "off" -> Off
    "unavailable" -> Unavailable
    value -> StateValue(value)
  }
  State(mapped_state_value, attributes)
}

fn map_to_boolean_state(state_value: String, attributes: Attributes) -> State {
  let mapped_state_value = case state_value {
    "on" -> On
    "off" -> Off
    value -> StateValue(value)
  }
  State(mapped_state_value, attributes)
}

fn map_to_binary_sensor_state(
  state_value: String,
  attributes: Attributes,
) -> State {
  let mapped_state_value = case state_value, attributes.device_class {
    "on", BatterySensor -> Low
    "on", BatteryCharging -> Charging
    "on", ColdSensor -> Cold
    "on", ConnectivitySensor -> Connected
    "on", DoorSensor -> Open
    "on", GarageDoorSensor -> Open
    "on", GasSensor -> GasDetected
    "on", HeatSensor -> Hot
    "on", LightSensor -> LightDetected
    "on", LockSensor -> Unlocked
    "on", MoistureSensor -> MoistureDetected
    "on", MotionSensor -> MotionDetected
    "on", MovingSensor -> Moving
    "on", OccupancySensor -> Occupied
    "on", OpeningSensor -> Open
    "on", PlugSensor -> PluggedIn
    "on", PowerSensor -> PluggedIn
    "on", PresenceSensor -> Home
    "on", ProblemSensor -> ProblemDetected
    "on", RunningSensor -> Running
    "on", SafetySensor -> Unsafe
    "on", SmokeSensor -> SmokeDetected
    "on", SoundSensor -> SoundDetected
    "on", TamperSensor -> TamperingDetected
    "on", UpdateSensor -> UpdateAvailable
    "on", VibrationSensor -> VibrationDetected
    "on", WindowSensor -> Open

    "off", BatterySensor -> Normal
    "off", BatteryCharging -> NotCharging
    "off", ColdSensor -> Normal
    "off", ConnectivitySensor -> Disconnected
    "off", DoorSensor -> Closed
    "off", GarageDoorSensor -> Open
    "off", GasSensor -> NoGas
    "off", HeatSensor -> Normal
    "off", LightSensor -> NoLight
    "off", LockSensor -> Locked
    "off", MoistureSensor -> NoMoisture
    "off", MotionSensor -> NoMotion
    "off", MovingSensor -> NotMoving
    "off", OccupancySensor -> NotOccupied
    "off", OpeningSensor -> Closed
    "off", PlugSensor -> Unplugged
    "off", PresenceSensor -> Away
    "off", ProblemSensor -> NoProblem
    "off", RunningSensor -> NotRunning
    "off", SafetySensor -> Safe
    "off", SmokeSensor -> NoSmoke
    "off", SoundSensor -> NoSound
    "off", TamperSensor -> NoTampering
    "off", UpdateSensor -> UpToDate
    "off", VibrationSensor -> NoVibration
    "off", WindowSensor -> Closed
    "unavailable", _ -> Unavailable
    value, _ -> StateValue(value)
  }
  State(mapped_state_value, attributes)
}

fn map_to_sensor_state(state_value: String, attributes: Attributes) -> State {
  let mapped_state_value = case attributes.device_class {
    AQISensor -> AirQualityIndex(state_value)
    BatterySensor -> Battery(state_value)
    CarbonDioxideSensor -> CarbonDioxide(state_value)
    CarbonMonoxideSensor -> CarbonMonoxide(state_value)
    CurrentSensor -> Current(state_value)
    DateSensor -> Date(state_value)
    EnergySensor -> Energy(state_value)
    FrequencySensor -> Frequency(state_value)
    GasSensor -> Gas(state_value)
    HumiditySensor -> Humidity(state_value)
    IlluminanceSensor -> Illuminance(state_value)
    MonetarySensor -> Monetary(state_value)
    NitrogenDioxideSensor -> NitrogenDioxide(state_value)
    NitrogenMonoxideSensor -> NitrogenMonoxide(state_value)
    NitrousOxideSensor -> NitrousOxide(state_value)
    OzoneSensor -> Ozone(state_value)
    PM1Sensor -> PM1(state_value)
    PM10Sensor -> PM10(state_value)
    PM25Sensor -> PM25(state_value)
    PowerFactorSensor -> PowerFactor(state_value)
    PowerSensor -> Power(state_value)
    PressureSensor -> Pressure(state_value)
    SignalStrengthSensor -> SignalStrength(state_value)
    SulphurDioxideSensor -> SulphurDioxide(state_value)
    TemperatureSensor -> Temperature(state_value)
    TimestampSensor -> Timestamp(state_value)
    VolatileOrganicCompoundsSensor -> VolatileOrganicCompounds(state_value)
    VoltageSensor -> Voltage(state_value)
    _ -> StateValue(state_value)
  }

  State(mapped_state_value, attributes)
}
