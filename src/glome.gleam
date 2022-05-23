import gleam/io
import gleam/option.{Some}
import glome/homeassistant.{HomeAssistant, add_handler}
import glome/homeassistant/state_change_event.{StateChangeEvent}
import glome/homeassistant/entity_selector.{All, EntitySelector}
import glome/homeassistant/domain.{MediaPlayer}
import glome/homeassistant/environment.{Configuration}

pub fn main() {
  assert Some(token) = environment.get_access_token()
  assert Ok(_) =
    homeassistant.connect(
      Configuration("192.168.178.62", 8123, token),
      fn(home_assistant: HomeAssistant) {
        home_assistant
        |> add_handler(
          for: EntitySelector(MediaPlayer, All),
          handler: all_lights_handler,
        )
      },
    )
}

fn all_lights_handler(data: StateChangeEvent, _home_assistant: HomeAssistant) {
  io.debug(data)
  Ok(Nil)
}
