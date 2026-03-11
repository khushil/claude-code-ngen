import Config

config :platform,
  claude_executable: "claude",
  default_model: nil,
  default_effort: nil,
  default_max_budget: nil,
  agent_timeout: 300_000,
  permission_mode: "bypassPermissions"

config :logger,
  level: :info

import_config "#{config_env()}.exs"
