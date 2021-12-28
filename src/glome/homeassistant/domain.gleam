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

pub fn from_string(domain: String) -> Domain {
  case domain {
    "alarm_control_panel" -> AlarmControlPanel
    "binary_sensor" -> BinarySensor
    "button" -> Button
    "calendar" -> Calendar
    "camera" -> Camera
    "climate" -> Climate
    "cover" -> Cover
    "device_tracker" -> DeviceTracker
    "fan" -> Fan
    "group" -> Group
    "humidifier" -> Humidifier
    "input_boolean" -> InputBoolean
    "light" -> Light
    "lock" -> Lock
    "media_player" -> MediaPlayer
    "number" -> Number
    "person" -> Person
    "remote" -> Remote
    "select" -> Select
    "sensor" -> Sensor
    "sun" -> Sun
    "switch" -> Switch
    "vacuum" -> Vacuum
    "water_heater" -> WaterHeater
    "weather" -> Weather
    "zone" -> Zone
    domain -> Domain(domain)
  }
}

pub external fn to_string(Domain) -> String =
  "erlang" "atom_to_binary"
