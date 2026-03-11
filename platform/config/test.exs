import Config

config :platform,
  claude_executable: Path.expand("../test/support/mock_claude.sh", __DIR__),
  agent_timeout: 10_000

config :logger,
  level: :warning
