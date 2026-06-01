# Hermes Agent on Zerops

Run [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) —
the self-improving AI agent with persistent memory + skills — on
[Zerops](https://zerops.io), with **durable state across deploys** and a
**git-push CI/CD** workflow.

## Deploy

1. **Import the project** — `zerops-project-import.yaml` creates the `hermes`
   runtime + an `storage` object-storage service and does a first build:
   ```sh
   zcli project project-import zerops-project-import.yaml
   ```
   (or use the dashboard's *Import project* / "Deploy to Zerops").
2. **Set your LLM key** — on the `hermes` service add ONE secret:
   `OPENROUTER_API_KEY` (or `OPENAI_API_KEY` / `ANTHROPIC_API_KEY`). See
   `.env.example` for everything Hermes reads.
3. **Wire CI/CD** — connect this repo in the Zerops dashboard
   (*Service → Build/deploy → connect Git*). From then on every `git push`
   rebuilds and redeploys. State is preserved (see below).

## Accessing the dashboard — one env switch

`DASHBOARD_MODE` controls how the admin dashboard (Keys / Config / Sessions) is exposed:

| `DASHBOARD_MODE` | Exposure | Access |
|---|---|---|
| `private` *(default)* | none public — keep the subdomain **off** | `zcli vpn up` → `http://hermes:9119` |
| `oauth` | public subdomain, **gated by OAuth login** | turn the subdomain **on**, set the `DASHBOARD_OAUTH_*` + `HERMES_DASHBOARD_PUBLIC_URL` secrets |

Private is secure-by-default (no public admin panel). Flip to `oauth` for a public demo.

## How state survives CI/CD (the important part)

Every deploy is a **fresh container**, so the agent's brain lives in object
storage, not the container:

- **3 SQLite DBs** (`state.db` sessions, `kanban.db` tasks, `memory_store.db`
  memory) are streamed to the `storage` bucket continuously by **Litestream**
  and `litestream restore`d on every boot.
- **Committed in git:** `zerops.yaml`, `zerops-project-import.yaml`,
  `litestream.yml`, your `skills/`.
- **Runtime state (object storage, not git):** sessions, memory, learned skills.

So a `git push` redeploys the code without wiping the agent's memory.

## Adding skills

Drop folders under `skills/` (each a `SKILL.md` + optional scripts), commit,
push. The build merges them into Hermes's bundled skills. See `skills/README.md`.

## How the build works

`zerops.yaml` installs the official Hermes **wheel** (which ships the prebuilt
dashboard), overlays the `dashboard_auth` namespace package + bundled `skills`
from source (both are excluded from the wheel), and runs three supervised
processes: `litestream`, `hermes gateway`, and the dashboard. Pinned to Hermes
`v0.15.2`.
