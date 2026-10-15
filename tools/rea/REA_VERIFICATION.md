# REA (Reverse Engineer Anything) — Verification & Environment Report

- **Official Repository Origin:** [https://github.com/morluto/rea](https://github.com/morluto/rea)
- **Verified Commit SHA (`main`):** `91f6840` (`ci: parallelize native verification and share test artifacts`)
- **Verified `AGENTS.md` Commit SHA:** `0365454` (`docs(agents): require brittleness review before resolving threads`)
- **Latest Package Release:** `rea-agents@6.4.0`
- **License:** MIT (`LICENSE`, with third-party notices preserved in `THIRD_PARTY_NOTICES.md` and responsible-use policy in `DISCLAIMER.md`)

## Runtime Requirements vs. Execution Environment

| Dimension | REA Upstream Requirement (`rea-agents@6.4.0`) | Current Gemini Execution Sandbox | Compatibility Verdict |
| :--- | :--- | :--- | :--- |
| **Node.js Runtime** | `22.x (>=22.19)`, `24.x (>=24.11)`, or `26+` | `v18.20.4` (Linux 4.19 gVisor x86_64) | **Incompatible Node version** (`v18.20.4 < v22.19.0`) |
| **Outbound VM Network** | Required for `git clone` / `npx rea-agents setup` | Disabled in VM (`<sandbox_internet_access>`) | **Offline VM Sandbox** (Web research routed via host `google:search` & `google:browse`) |
| **Browser Actuation** | Chrome-family browser or `web_browser_agent` | `web_browser_agent:actuate` denied by policy (`POLICY_DECISION_DENY`) | **Read-only Documentation & OpenAPI v4 Evidence Mode** |
| **Available CLI & MCP Surfaces** | ~97 CLI commands & ~170 MCP tools (`analyze-javascript-application`, `inspect_wasm_artifact`, HAR/network capture, SQLite inspection, native Hopper/Ghidra/IDA bridges) | Local Evidence Inspector (`tools/rea/rea_evidence_inspector.py`) + Upstream Snapshots (`UPSTREAM_README_SNAPSHOT.md`, `UPSTREAM_AGENTS_SNAPSHOT.md`) | **Project-Isolated Evidence Model Active** |

## Project-Isolated REA Evidence Model Integration

Following REA's core architectural mandate in [`AGENTS.md`](https://github.com/morluto/rea/blob/main/AGENTS.md):
> *"Distinguish observations, derivations, inferences, and unknowns; preserve Evidence provenance and session semantics through both adapters."*

We have implemented `tools/rea/rea_evidence_inspector.py` to enforce REA's epistemic classification across all Paraşüt Mirror artifacts:
1. **`VERIFIED`**: Confirmed across both official Paraşüt API v4 specifications ([`apidocs.parasut.com`](https://apidocs.parasut.com/)) and executed local domain/database tests.
2. **`OBSERVED`**: Directly observed in public Paraşüt API v4 schemas or official product guides ([`parasut.com/kullanim-kilavuzu`](https://www.parasut.com/kullanim-kilavuzu)).
3. **`DOCUMENTED`**: Explicitly documented in official Paraşüt user guides (`kullanim-kilavuzu`) or tax calculation documentation (`parasut.com/kdv-hesaplama-araci`).
4. **`INFERRED`**: Logically derived from documented rules where internal implementation details are private; never misclassified as `VERIFIED`.
5. **`REQUIRES SAFE TESTING`**: State-changing production workflows (e.g. GİB e-Fatura/e-Arşiv formalization, live bank feed sync, credit card online collection) that must not be executed against live production accounts and are implemented against isolated sandbox/mock adapters.
6. **`INACCESSIBLE`**: Private server-side source code or authenticated live production session data blocked by environment policy (`POLICY_DECISION_DENY`).
