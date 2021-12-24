import gleam/io
import homeassistant
import homeassistant.{
  AccessToken, Attributes, BinarySensor, Configuration, EntityId, InputBoolean, Light,
  Off, On, Sensor, StateChangeEvent, StateChangeHandlers, register_handler,
}
import gleam/otp/process.{Receiver}
import nerf/websocket.{Connection}
import gleam/result
import gleam/map
import gleam/dynamic
import json

external fn get_env(String) -> Result(String, Nil) =
  "system" "get_var"

pub fn main() {
  assert Ok(token) = get_env("ACCESS_TOKEN")
  assert Ok(_) =
    homeassistant.connect(
      Configuration("192.168.178.62", 8123, AccessToken(token)),
      fn(handlers: StateChangeHandlers) {
        handlers
        |> register_handler(
          for: EntityId(InputBoolean, "*"),
          handler: input_boolean_handler,
          predicate: got_turned_on,
        )
      },
    )
}

fn input_boolean_handler(data: StateChangeEvent) {
  io.println("")
  io.println("### Event handler ###")
  io.println("")
  let Attributes(attributes) = data.old_state.attributes

  data
  |> io.debug
  io.println("")
  io.println("### ############ ###")
  Ok(Nil)
}

fn got_turned_on(data: StateChangeEvent) {
  data.old_state.value == Off && data.new_state.value == On
}
