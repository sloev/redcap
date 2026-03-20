# Specification: Redcap CMS (Redbean + Fullmoon + SQLite)

## 1. Overview & Core Philosophy
**Redcap** is a single-file, portable Content Management System. It acts as the web server, database, admin interface, and public website, all contained within a single `.com` Actually Portable Executable (APE). 

**Core Objectives:**
*   **True Atomic Singularity:** The executable file *is* the entire website. It contains the binary, logic, assets, and the **live SQLite database** within its own ZIP structure.
*   **Zero-Dependency Portability:** Runs natively on 6+ OSs without external runtimes.
*   **Self-Baking Persistence:** Uses `StoreAsset()` to commit database changes back into the running binary.
*   **100% Browser-Configurable:** Build everything from schemas to layouts in the GUI.

## 2. Architecture & Redbean Integration
Redcap leverages the following native Redbean capabilities to minimize custom code:
*   **Persistence:** `lsqlite3` for data management and `StoreAsset()` for internal ZIP storage.
*   **Security:** `argon2` for auth, cryptographically signed session cookies, and `pledge` sandboxing.
*   **Networking:** `Fetch()` API for the Fleet Commander reverse proxy and external webhooks.
*   **Encoding:** High-performance `EncodeJson`/`DecodeJson` and `Base64`/`Hex` utilities.
*   **Robustness:** Lazy DB handle initialization in `OnHttpRequest` to ensure fork-boundary safety.

## 3. Orchestration: Fleet Provisioner & Autonomous Instances
Instead of a centralized proxy, each Redcap instance operates as a fully autonomous, self-healing process integrated directly with the host OS. The **Fleet Provisioner** is a purely administrative tool.
*   **Autonomous Lifecycle:** Each atomic Redcap file has a dedicated `systemd` service (or equivalent), ensuring it starts on boot, restarts on failure, and operates entirely independently of the Fleet Provisioner.
*   **Edge Server Integration:** Redcap interfaces directly with Edge Servers (Nginx/Caddy). The Fleet Provisioner's only job is to generate the appropriate proxy configuration snippets and deploy the atomic binary.
*   **Decentralized Resilience:** If the Fleet Provisioner is turned off or deleted, all deployed Redcap instances continue to function, serve traffic, and self-heal.

## 4. Professional Content Management
*   **Nested Fields:** Complex data structures (lists of objects).
*   **Content Workflow:** Draft vs. Published states.
*   **Side-by-Side Preview:** Live rendering during content authoring.
*   **Bulk Media Pipeline:** Batch upload with automated WebP/Resizing optimization.
*   **Search & Filters:** Global full-text search in SQLite.

## 5. Advanced Collaboration
*   **Collaborative Presence:** Real-time visual indicators of active editors.
*   **Real-time Admin Chat:** Coordination system for managers.

## 6. Starter Templates
1.  **Blog:** Atomic file with post schemas and feed layouts.
2.  **Portfolio:** Atomic file optimized for media grids.
3.  **Appliance:** A clean, minimal starter for custom builds.

## 7. Security & Robustness Mandates
*   **Zero-Trust:** Argon2id auth + Signed Cookies + CSP.
*   **Self-Healing:** Startup `integrity_check` + Automated `.bak` rotation.
*   **Graceful Errors:** Exception-safe layout rendering with safe fallbacks.

## 8. Security & Risk Audit (Findings & Mitigations)
| Risk ID | Finding | Severity | Mitigation Strategy |
| :--- | :--- | :--- | :--- |
| **SEC-01** | **Command Injection:** Unsanitized parameters in Fleet `os.execute` calls. | **Critical** | Implement strict regex validation for all site/domain names. |
| **SEC-02** | **CSRF:** Missing Cross-Site Request Forgery protection on APIs. | **Medium** | Enforce `SameSite=Strict` cookies and validate `Origin`/`Referer` headers. |
| **SEC-03** | **XSS:** Injection of scripts via Layout Editor or Markdown. | **Medium** | Implement a restrictive Content Security Policy (CSP) and HTML sanitization. |
| **SEC-04** | **Unauthenticated Fleet:** Missing login flow for Fleet Commander. | **Medium** | Implement Argon2 auth for the Fleet Dashboard. |
| **SEC-05** | **Binary Mutation:** Self-modifying binary risk if worker is compromised. | **Medium** | Use `pledge` to limit write access and recommend read-only binary deployments for high-security sites. |
| **SEC-06** | **Resource Exhaustion:** No rate-limiting on CPU-intensive `Bake to ZIP`. | **Low** | Implement rate-limiting and task queuing for binary persistence. |

## 9. Current Progress & State
- [x] Redbean + Fullmoon Bootstrap
- [x] Fork-Safe SQLite Management
- [x] Atomic ZIP Persistence (`Bake to ZIP`)
- [x] Unified Admin Dashboard
- [x] Visual Builders (Schemas & Content)
- [x] Settings Plane & SEO Tags
- [x] Starter Templates (Blueprints)
- [x] Draft/Published Workflow
- [x] Pure-Lua Markdown Engine
- [x] Autonomous Lifecycle (Systemd Integration)
- [x] Fleet Provisioner (Nginx/Caddy Config Gen)
- [x] Security Mitigation: SEC-01 to SEC-04
- [x] Nested Fields Support (Simple Arrays)
- [x] Media Optimization Pipeline (Client-Side WebP/Resize)
- [x] Collaborative Presence & Admin Chat
- [x] Automated Backups & Integrity Checks (Robustness)
- [x] Headless API
- [x] Form Inbox
- [x] In-Browser Monaco Editor
- [x] Side-by-Side Content Preview
- [x] Static Site Export (SSG)
- [x] Advanced Multi-Language (I18n)
- [ ] Visual Layout Block Designer (Phase 4)
