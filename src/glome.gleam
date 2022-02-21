import gleam/io
import gleam/otp/process.{Receiver}
import nerf/websocket.{Connection}
import gleam/option.{Some}
import gleam/result
import gleam/map
import gleam/dynamic
import glome/homeassistant.{
  HomeAssistant, StateChangeHandlers, add_constrained_handler, add_handler, call_service,
  get_state,
}
import glome/core/authentication.{AccessToken}
import glome/homeassistant/state_change_event.{StateChangeEvent}
import glome/homeassistant/entity_id.{EntityId}
import glome/homeassistant/domain.{Cover, InputBoolean, Light}
import glome/homeassistant/state.{MotionDetected, Normal, Off, On}
import glome/core/json
import glome/homeassistant/environment.{Configuration}

pub fn main() {
  assert Some(token) = environment.get_access_token()
  assert Ok(_) =
    homeassistant.connect(
      Configuration("192.168.178.62", 8123, AccessToken(token)),
      fn(home_assistant: HomeAssistant) {
        home_assistant
        |> add_constrained_handler(
          for: EntityId(BinarySensor, "*"),
          handler: motion_sensor_handler,
          constraint: motion_detected
        )
      },
    )
}

fn motion_sensor_handler(data: StateChangeEvent, home_assistant: HomeAssistant) {
  try light_state =
    home_assistant
    |> get_state(of: EntityId(Light, "main_downstairs"))
    
  Ok(Nil)
}

fn motion_detected(data: StateChangeEvent, home_assistant: HomeAssistant) {
  data.old_state.value == Normal && data.new_state.value == MotionDetected
}
