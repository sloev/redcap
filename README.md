# Redcap CMS 🚩

**Redcap** is a radically portable, atomic, and zero-dependency Content Management System (CMS) built on the revolutionary **Redbean** Actually Portable Executable (APE) server.

The entire CMS—including the web server, database, administrative interface, and your public website—lives inside a **single executable file**.

## 🚀 Core Philosophy: True Atomic Singularity

Redcap is designed to be a "site-in-a-can." 

*   **Atomic Singularity:** One file (`.com`) contains your binary, assets, logic, and **live SQLite database**.
*   **Self-Baking:** Use the "Bake to ZIP" feature to commit your database state directly into the executable's ZIP structure. 
*   **Actually Portable:** Runs natively on Linux, macOS, Windows, FreeBSD, NetBSD, and OpenBSD with zero installation.
*   **100% Browser-Configurable:** Build your site schemas, author content, and design layouts entirely through the web GUI.

## ✨ Key Features

*   **Visual Schema Builder:** Drag-and-drop fields (Text, Markdown, Number, Lists) to define content models.
*   **Live Side-by-Side Preview:** See your rendered page update in real-time as you author content.
*   **Monaco Editor:** A professional IDE-grade layout editor powered by the same engine as VS Code.
*   **Media Optimization:** Automatic client-side image resizing and WebP conversion.
*   **I18n (Multi-Language):** Native support for content localization and routing.
*   **Robustness Suite:** Built-in SQLite integrity checks and automated 24-hour rotating backups.
*   **Fleet Provisioner:** Easily deploy and manage a fleet of autonomous Redcap instances with automated Nginx/Caddy configuration generation.
*   **Static Site Export:** One-click export of your dynamic site into a flat HTML ZIP for high-performance static hosting.

## ⚖️ Comparison: GitHub Pages vs. Redcap CMS

| Feature | GitHub Pages | Redcap CMS |
| :--- | :--- | :--- |
| **Setup Time** | ~5 Minutes | ~30 Seconds |
| **Architecture** | Centralized (SaaS) | Decentralized (Appliance) |
| **Authoring** | **Dev-Only:** Git, Markdown, Editor. | **Everyone:** Visual Builders in browser. |
| **Data** | Flat Files only. | **Live SQLite Database.** |
| **Editing** | Push -> Build -> Deploy (~2 min). | **Instant Save** (0 seconds). |
| **Portability** | Locked to GitHub's infrastructure. | **Move the file, move the site.** |
| **Headless API** | None (unless you build one). | **Native JSON API** generated automatically. |
| **Mobile Edit** | Hard (requires specialized apps). | **Native** (works perfectly in Safari/Chrome). |

## 🛠️ Getting Started

1.  **Download:** Grab the latest `redcap.com` binary.
2.  **Initialize:** Create your first admin user:
    ```bash
    ./redcap.com -- --init-admin="YourSecurePassword"
    ```
3.  **Run:** Launch the server (the `-*` flag enables self-modifying "Baking"):
    ```bash
    ./redcap.com -p 8080 -*
    ```
4.  **Build:** Navigate to `http://localhost:8080/admin` and start creating.

## 📦 Atomic Deployment

To move your site to a new server, simply copy the single `mysite.com` file. No database migrations, no environment variables, no `npm install`.

## 📜 License

Public Domain / ISC (Inherited from Redbean). Build freely.
