# Your skills

Drop your own Hermes skills in this folder, commit, and push — the build merges
them into Hermes's bundled skill set (`HERMES_BUNDLED_SKILLS`) on every deploy.

A skill is a folder containing a `SKILL.md` (plus any scripts it needs):

```
skills/
└── my-skill/
    └── SKILL.md
```

See `hello-zerops/` for a minimal example. Skills Hermes *learns* at runtime are
stored separately in object storage (not here) and restored on boot.
