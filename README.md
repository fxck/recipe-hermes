# Hermes Agent on Zerops

Run [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) —
the self-improving AI agent with persistent memory + skills — on
[Zerops](https://zerops.io), with **durable state across deploys** and a
**git-push CI/CD** workflow.

## Why Zerops is the best way to run Hermes

Hermes is awkward to host well: it's **always-on**, **stateful** (its worth is the
memory and skills it accumulates), **single-instance** (per-instance SQLite), and a
**heavy tool user** (it shells out to ripgrep/ffmpeg/node, drives a browser, writes
files). That mix defeats the usual options:

- a **raw VPS** works but becomes a hand-tended snowflake — no CI/CD, manual backups,
  you run the supervisor and VPN yourself, and a rebuild can lose the agent's memory;
- **serverless** can't host a long-lived gateway + cron or run Hermes's tool backends;
- **plain containers** are reproducible but ephemeral — a redeploy wipes the brain.

It's the classic **pet-vs-cattle** tension: you want push-to-deploy infrastructure,
but the agent is a *pet* whose memory must survive. This recipe resolves it:

| Hermes needs | How this setup delivers it |
|---|---|
| Memory that survives redeploys | managed **object storage** + **Litestream** restore-on-boot — `git push` redeploys the code, never the brain |
| A real OS for its tools | full **Linux container** (SSH, sudo, apt, browser, ffmpeg) — Hermes runs exactly as upstream intends |
| To stay up 24/7 | **supervised** processes with auto-restart + zero-downtime rolling deploys |
| Bursty load (idle → heavy agent runs) | **vertical autoscaling** of CPU/RAM + grow-only disk — no overpay, no mid-task OOM |
| Durable storage without ops | object storage wired by hostname, no external S3 account; managed Postgres one line away for self-hosted Honcho memory |
| Push-to-deploy | built-in **git CI/CD** — no pipeline, registry, or deploy scripts to maintain |
| Not exposing an admin panel | project-private network; dashboard over the **Zerops VPN** by default, OAuth-gated public only by choice |

The payoff: a Hermes that's **reproducible** (a thin repo, not a snowflake),
**durable** (its memory lives in object storage), **always-on**, **secure by
default**, and shipped by `git push`.

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
