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
import glome/homeassistant/domain.{InputBoolean, Light}
import glome/homeassistant/state.{Off, On}
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

  try resp =
    home_assistant
    |> get_state(EntityId(BinarySensor, "main_downstairs"))
  io.debug(resp)

  io.println("")
  io.println("### ############ ###")
  Ok(Nil)
}

fn got_turned_on(data: StateChangeEvent, home_assistant: HomeAssistant) {
  data.old_state.value == Off && data.new_state.value == On
}
