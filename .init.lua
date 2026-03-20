fm = require "fullmoon"
local db = require "db"
local api = require "api"
local markdown = require "markdown"

local function renderMarkdown(str)
    if not str then return "" end
    return markdown(str)
end

-- OnWorkerStart is the correct place to initialize worker-specific state
-- but we'll use lazy initialization via db.get_db() in handlers.

-- Check for arguments (runs once in parent process)
for i, v in ipairs(argv) do
  if v:find("^--init-admin=") then
    local password = v:match("^--init-admin=(.*)")
    if password and password ~= "" then
      print("Initializing database and admin user...")
      db.init_schema()
      db.add_admin("admin", password)
      print("Initialization complete.")
      os.exit(0)
    end
  end
end

-- Bootstrap DB from ZIP if local copy is missing
db.bootstrap_from_zip()

-- Robustness: Integrity Check and Automated Backup
if not db.run_integrity_check() then
    -- Enter Safe Mode or halt? For now, we'll just log loudly
    Log(kLogError, "DATABASE CORRUPTION DETECTED. SITE MAY BE UNSTABLE.")
end
db.perform_backup()

-- Persistent Session Secret
local secret
local d = db.get_db()
local stmt = d:prepare("SELECT value FROM settings WHERE key = 'session_secret'")
if stmt:step() == db.sqlite3.ROW then
    secret = stmt:get_value(0)
else
    secret = EncodeBase64(GetRandomBytes(32))
    local stmt_set = d:prepare("INSERT INTO settings (key, value) VALUES ('session_secret', ?)")
    stmt_set:bind_values(secret)
    stmt_set:step()
    stmt_set:finalize()
end
stmt:finalize()

fm.sessionOptions.secret = secret

-- Get Global Settings for SEO
local global_settings = {}
for row in d:nrows("SELECT key, value FROM settings") do
    global_settings[row.key] = row.value
end

-- Admin routes
fm.setRoute("/admin", fm.serveAsset("/admin/index.html"))
fm.setRoute("/admin/dashboard", api.dashboard_handler)
fm.setRoute({"/admin/api/login", method = "POST"}, api.login_handler)
fm.setRoute("/admin/api/settings", api.get_settings)
fm.setRoute({"/admin/api/settings", method = "POST"}, api.save_settings)
fm.setRoute("/admin/api/schemas", api.get_schemas)
fm.setRoute({"/admin/api/schemas", method = "POST"}, api.save_schema)
fm.setRoute("/admin/api/content/:schema_id", api.get_content)
fm.setRoute({"/admin/api/content/:schema_id", method = "POST"}, api.save_content)
fm.setRoute("/admin/api/content/search/:slug", api.find_by_slug)
fm.setRoute("/admin/api/users", api.get_users)
fm.setRoute({"/admin/api/users", method = "POST"}, api.create_user)
fm.setRoute("/admin/api/layouts", api.get_layouts)
fm.setRoute({"/admin/api/layouts", method = "POST"}, api.save_layout)
fm.setRoute("/admin/api/media", api.get_media_list)
fm.setRoute({"/admin/api/media", method = "POST"}, api.upload_media)
fm.setRoute("/admin/api/history", api.get_history)
fm.setRoute("/admin/api/blueprints", api.get_blueprints)
fm.setRoute({"/admin/api/blueprints", method = "POST"}, api.apply_blueprint)
fm.setRoute({"/admin/api/persist", method = "POST"}, api.persist_db)
fm.setRoute("/admin/api/maintenance/download", api.download_db)
fm.setRoute("/admin/api/maintenance/backups", api.list_backups)
fm.setRoute({"/admin/api/presence", method = "POST"}, api.update_presence)

-- Headless API
fm.setRoute("/api/v1/:schema_name", api.public_api_list)
fm.setRoute("/api/v1/:schema_name/:slug", api.public_api_single)
fm.setRoute({"/api/v1/forms/:form_name", method = "POST"}, api.submit_form)
fm.setRoute("/admin/api/forms", api.get_forms)
fm.setRoute("/admin/api/export", api.export_static)

-- Public Media route
fm.setRoute("/media/:filename", api.serve_media)

-- Layout Resolution and Public Routes
fm.setRoute("/*", function(r)
  -- SEC-03 Mitigation: Global security headers
  SetHeader("Content-Security-Policy", "default-src 'self' 'unsafe-inline' unpkg.com; img-src 'self' data:;")
  SetHeader("X-Frame-Options", "SAMEORIGIN")
  SetHeader("X-Content-Type-Options", "nosniff")

  local d = db.get_db()
  local layout_html
  local stmt = d:prepare("SELECT html FROM layouts WHERE path = ?")
  stmt:bind_values(r.path)
  if stmt:step() == db.sqlite3.ROW then
    layout_html = stmt:get_value(0)
  end
  stmt:finalize()
  
  if not layout_html then
      local stmt_wild = d:prepare("SELECT html FROM layouts WHERE path = '/*'")
      if stmt_wild:step() == db.sqlite3.ROW then
          layout_html = stmt_wild:get_value(0)
      end
      stmt_wild:finalize()
  end

  if layout_html then
    local content_data = {}
    local slug = r.path:sub(2)
    if slug == "" then slug = "home" end
    local lang = r.params.lang or global_settings.default_lang or 'en'
    
    local content_stmt = d:prepare("SELECT data FROM content WHERE slug = ? AND lang = ? AND status = 'published'")
    content_stmt:bind_values(slug, lang)
    if content_stmt:step() == db.sqlite3.ROW then
        local raw_json = content_stmt:get_value(0)
        content_data = DecodeJson(raw_json)
    end
    content_stmt:finalize()
    
    local vars = {
        path = r.path, 
        data = content_data,
        site_title = global_settings.site_title or "Redcap CMS",
        site_description = global_settings.site_description or "",
        domain = global_settings.domain or "",
        db = d,
        DecodeJson = DecodeJson,
        renderMarkdown = renderMarkdown
    }
    
    local rendered = fm.render(layout_html, vars)
    local seo_tags = string.format([[
<title>%s%s</title>
<meta name="description" content="%s">
]], vars.site_title, (content_data.title and (" | " .. content_data.title) or ""), vars.site_description)

    rendered = rendered:gsub("<head>", "<head>" .. seo_tags)
    
    -- Inject Edit Overlay for Admins
    if r.session.username then
        local edit_button = string.format([[
<div id="redcap-admin-overlay" style="position:fixed;bottom:20px;right:20px;z-index:9999;">
    <a href="/admin#tab=content&slug=%s" style="background:#3498db;color:white;padding:10px 20px;border-radius:30px;text-decoration:none;font-family:sans-serif;box-shadow:0 4px 12px rgba(0,0,0,0.2);font-weight:bold;display:flex;align-items:center;gap:10px;">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>
        Edit Page
    </a>
</div>
]], slug)
        rendered = rendered:gsub("</body>", edit_button .. "</body>")
    end
    
    return rendered
  end
  
  if r.path == "/" then
    return "Redcap CMS is active."
  end
  
  return fm.serveError(404)
end)

fm.run()
