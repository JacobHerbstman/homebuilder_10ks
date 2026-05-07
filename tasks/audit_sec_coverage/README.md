# SEC 10-K Acquisition And Coverage Audit

This task is the end-to-end entry point for the first SEC 10-K acquisition pass. It chases the upstream task chain:

`build_builder_sec_crosswalk -> fetch_sec_submissions -> build_sec_10k_filing_index -> fetch_sec_10k_filings -> extract_10k_land_candidates -> audit_sec_coverage`

The SEC fetch tasks require a declared user agent. This is not a password or API key. It is contact information sent in the HTTP request header so the SEC can identify automated traffic. Each person running the replication package should use their own name, organization, or project contact email rather than reusing another researcher's identity.

For a fresh clone, copy the example environment file at the repo root:

```bash
cp .env.example .env
```

Then edit `.env` so `SEC_USER_AGENT` identifies the person or project running the scraper:

```bash
SEC_USER_AGENT="Your Name your.email@example.com"
SEC_REQUESTS_PER_SECOND=4
SEC_PULL_DATE=20260507
```

Run the task with Make:

```bash
cd /path/to/homebuilder_10ks
cd tasks/audit_sec_coverage/code
make
```

The SEC fetch task Makefiles symlink the repo-root `.env` into their task-local `input/` folders and source that symlink before calling Python. If `.env` is missing, Make stops with a setup error telling the runner to copy `.env.example` and set `SEC_USER_AGENT`.

`SEC_REQUESTS_PER_SECOND=4` keeps requests well below the SEC maximum. `SEC_PULL_DATE` fixes the raw-data cache folder date so a replication run writes to a deterministic raw directory. Set `SEC_FORCE=1` in `.env` only if you intentionally want to refresh already-cached SEC files.

The local `.env` file is ignored by git. Do not commit personal contact information or hard-code a user agent in the Python fetch scripts.
