# LLM Queue

A lightweight Rails API that queues and processes LLM requests through Ollama. Requests are submitted to named queues with configurable priorities, processed in the background via Solid Queue, and results are stored for later retrieval.

Built to run on a Raspberry Pi alongside other services.

## Stack

- Ruby 4.0 / Rails 8.1 (API-only)
- PostgreSQL
- Solid Queue (background jobs)
- Ollama (LLM inference)

## Local Development

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

Expects PostgreSQL running locally and Ollama at `http://localhost:11434`.

## Tests

```bash
bin/rails test
```

## Docker

```bash
export RAILS_MASTER_KEY=$(cat config/master.key)
docker compose up --build -d
```

The API runs on port 4100 by default.

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `RAILS_MASTER_KEY` | -- | Required. From `config/master.key` |
| `POSTGRES_PASSWORD` | `password` | Database password |
| `PORT` | `4100` | Host port for the API |
| `OLLAMA_BASE_URL` | `http://host.docker.internal:11434` | Ollama server URL |
| `OLLAMA_MODEL` | `qwen3.5:2b` | Model to use for inference |
| `OLLAMA_TIMEOUT` | `300` | Request timeout in seconds |

All of these can be set in a `.env` file next to `docker-compose.yml`.
