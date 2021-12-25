import gleam/io
import homeassistant
import homeassistant.{
  AccessToken, Attributes, BinarySensor, Configuration, EntityId, HomeAssistant,
  InputBoolean, Light, Off, On, Sensor, StateChangeEvent, StateChangeHandlers, add_constrained_handler,
  add_handler,
}
import gleam/otp/process.{Receiver}
import nerf/websocket.{Connection}
import gleam/result
import gleam/map
import gleam/dynamic
import json
import environment

pub fn main() {
  assert Ok(token) = environment.get_env("ACCESS_TOKEN")
  assert Ok(_) =
    homeassistant.connect(
      Configuration("192.168.178.62", 8123, AccessToken(token)),
      fn(home_assistant: HomeAssistant) {
        home_assistant
        |> add_constrained_handler(
          for: EntityId(InputBoolean, "*"),
          handler: input_boolean_handler,
          constraint: got_turned_on,
        )
      },
    )
}

fn input_boolean_handler(data: StateChangeEvent, home_assistant: HomeAssistant) {
  io.println("")
  io.println("### Event handler ###")
  io.println("")
  data
  |> io.debug
  io.println("")
  io.println("### ############ ###")
  Ok(Nil)
}

fn got_turned_on(data: StateChangeEvent, home_assistant: HomeAssistant) {
  data.old_state.value == Off && data.new_state.value == On
}
