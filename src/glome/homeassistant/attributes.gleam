import gleam/dynamic.{DecodeError, Dynamic, field, optional, string}
import gleam/result
import gleam/option.{Option}
import glome/core/serde
import glome/core/error.{GlomeError}
import glome/homeassistant/domain.{BinarySensor, Domain, MediaPlayer, Sensor}

pub type DeviceClass {
  //MediaPlayer
  TV
  Speaker
  MediaReceiver

  GasSensor
  BatterySensor
  PowerSensor

  // BinarySensor
  BatteryCharging
  ColdSensor
  ConnectivitySensor
  DoorSensor
  GarageDoorSensor
  HeatSensor
  LightSensor
  LockSensor
  MoistureSensor
  MotionSensor
  MovingSensor
  OccupancySensor
  OpeningSensor
  PlugSensor

  PresenceSensor
  ProblemSensor
  RunningSensor
  SafetySensor
  SmokeSensor
  SoundSensor
  TamperSensor
  UpdateSensor
  VibrationSensor
  WindowSensor

  //Sensor
  AQISensor
  CarbonDioxideSensor
  CarbonMonoxideSensor
  CurrentSensor
  DateSensor
  EnergySensor
  FrequencySensor
  HumiditySensor
  IlluminanceSensor
  MonetarySensor
  NitrogenDioxideSensor
  NitrogenMonoxideSensor
  NitrousOxideSensor
  OzoneSensor
  PM1Sensor
  PM10Sensor
  PM25Sensor
  PowerFactorSensor
  PressureSensor
  SignalStrengthSensor
  SulphurDioxideSensor
  TemperatureSensor
  TimestampSensor
  VolatileOrganicCompoundsSensor
  VoltageSensor
  //Default
  UnknownDeviceClass
  DeviceClass(String)
}

pub type Attributes {
  Attributes(
    friendly_name: Option(String),
    device_class: DeviceClass,
    raw: Dynamic,
  )
}

pub fn decoder(
  data: Dynamic,
  domain: Domain,
) -> Result(Attributes, List(DecodeError)) {
  let device_class =
    field("device_class", string)(data)
    |> result.unwrap("unknown_device_class")
    |> map_device_class_by_domain(domain)

  try friendly_name = field("friendly_name", optional(string))(data)

  Attributes(
    friendly_name: friendly_name,
    device_class: device_class,
    raw: data,
  )
  |> Ok
}

pub fn from_dynamic_and_domain(
  attributes_message: Dynamic,
  domain: Domain,
) -> Result(Attributes, GlomeError) {
  let device_class_value =
    serde.get_field_by_path(attributes_message, "device_class")
    |> result.then(serde.get_field_as_string)
    |> result.unwrap("unknown_device_class")

  let device_class = map_device_class_by_domain(device_class_value, domain)

  let friendly_name =
    serde.get_field_by_path(attributes_message, "friendly_name")
    |> result.then(serde.get_field_as_string)
    |> option.from_result

  Ok(Attributes(
    device_class: device_class,
    friendly_name: friendly_name,
    raw: attributes_message,
  ))
}

fn map_device_class_by_domain(
  device_class_value: String,
  domain: Domain,
) -> DeviceClass {
  case device_class_value, domain {
    //MediaPlayer
    "tv", MediaPlayer -> TV
    "speaker", MediaPlayer -> Speaker
    "receiver", MediaPlayer -> MediaReceiver

    "battery", Sensor -> BatterySensor
    "battery", BinarySensor -> BatterySensor

    // BinarySensor
    "battery_charging", BinarySensor -> BatteryCharging
    "cold", BinarySensor -> ColdSensor
    "connectivity", BinarySensor -> ConnectivitySensor
    "door", BinarySensor -> DoorSensor
    "garage_door", BinarySensor -> GarageDoorSensor
    "gas", BinarySensor -> GasSensor
    "heat", BinarySensor -> HeatSensor
    "light", BinarySensor -> LightSensor
    "lock", BinarySensor -> LockSensor
    "moisture", BinarySensor -> MoistureSensor
    "motion", BinarySensor -> MotionSensor
    "moving", BinarySensor -> MovingSensor
    "occupancy", BinarySensor -> OccupancySensor
    "opening", BinarySensor -> OpeningSensor
    "plug", BinarySensor -> PlugSensor
    "power", BinarySensor -> PowerSensor
    "presence", BinarySensor -> PresenceSensor
    "problem", BinarySensor -> ProblemSensor
    "running", BinarySensor -> RunningSensor
    "safety", BinarySensor -> SafetySensor
    "smoke", BinarySensor -> SmokeSensor
    "sound", BinarySensor -> SoundSensor
    "tamper", BinarySensor -> TamperSensor
    "update", BinarySensor -> UpdateSensor
    "vibration", BinarySensor -> VibrationSensor
    "window", BinarySensor -> WindowSensor

    //Sensor
    "aqi", Sensor -> AQISensor
    "carbon_dioxide", Sensor -> CarbonDioxideSensor
    "carbon_monoxide", Sensor -> CarbonMonoxideSensor
    "current", Sensor -> CurrentSensor
    "date", Sensor -> DateSensor
    "energy", Sensor -> EnergySensor
    "frequency", Sensor -> FrequencySensor
    "gas", Sensor -> GasSensor
    "humidity", Sensor -> HumiditySensor
    "illuminance", Sensor -> IlluminanceSensor
    "monetary", Sensor -> MonetarySensor
    "nitrogen_dioxide", Sensor -> NitrogenDioxideSensor
    "nitrogen_monoxide", Sensor -> NitrogenMonoxideSensor
    "nitrous_oxide", Sensor -> NitrousOxideSensor
    "ozone", Sensor -> OzoneSensor
    "pm1", Sensor -> PM1Sensor
    "pm10", Sensor -> PM10Sensor
    "pm25", Sensor -> PM25Sensor
    "power_factor", Sensor -> PowerFactorSensor
    "power", Sensor -> PowerSensor
    "pressure", Sensor -> PressureSensor
    "signal_strength", Sensor -> SignalStrengthSensor
    "sulphur_dioxide", Sensor -> SulphurDioxideSensor
    "temperature", Sensor -> TemperatureSensor
    "timestamp", Sensor -> TimestampSensor
    "volatile_organic_compounds", Sensor -> VolatileOrganicCompoundsSensor
    "voltage", Sensor -> VoltageSensor

    "unknown_device_class", _ -> UnknownDeviceClass
    value, _ -> DeviceClass(value)
  }
}
