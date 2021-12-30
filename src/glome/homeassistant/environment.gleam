import gleam/result
import gleam/int
import gleam/option.{None, Option}
import glome/core/authentication.{AccessToken}

pub type Configuration {
  Configuration(host: String, port: Int, access_token: AccessToken)
}

pub fn get_host() -> Option(String) {
  get_env("HOST")
  |> option.from_result
}

pub fn get_port() -> Option(Int) {
  get_env("PORT")
  |> result.then(int.parse)
  |> option.from_result
}

pub fn get_access_token() -> Option(String) {
  get_env("ACCESS_TOKEN")
  |> option.from_result
}

pub external fn get_env(String) -> Result(String, Nil) =
  "system" "get_var"
