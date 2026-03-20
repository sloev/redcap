local fm = require "fullmoon"
local db = require "db"
local blueprints = require "blueprints"

local function check_session(r)
  if not r.session.username then
    return fm.serveRedirect("/admin")
  end
  -- SEC-02 Mitigation: Basic CSRF check for mutations
  if r.method == "POST" or r.method == "PUT" or r.method == "DELETE" then
      local origin = GetHeader("Origin")
      local host = GetHeader("Host")
      if origin and not origin:find(host, 1, true) then
          return "Forbidden: CSRF detected", {status = 403}
      end
  end
end

local function save_history(item_type, item_id, old_val, new_val, user)
    local d = db.get_db()
    local stmt = d:prepare("INSERT INTO history (item_type, item_id, old_value, new_value, updated_by) VALUES (?, ?, ?, ?, ?)")
    stmt:bind_values(item_type, item_id, old_val, new_val, user)
    stmt:step()
    stmt:finalize()
end

local function login_handler(r)
  local username = r.params.username
  local password = r.params.password
  
  local d = db.get_db()
  local stmt = d:prepare("SELECT password_hash FROM users WHERE username = ?")
  stmt:bind_values(username)
  if stmt:step() == db.sqlite3.ROW then
    local hash = stmt:get_value(0)
    local argon2 = require "argon2"
    if argon2.verify(hash, password) then
      r.session.username = username
      r.session.role = "admin"
      return fm.serveRedirect("/admin/dashboard")
    end
  end
  stmt:finalize()
  
  return "Login failed."
end

local function dashboard_handler(r)
  local err = check_session(r)
  if err then return err end
  return fm.serveAsset("/admin/dashboard.html")
end

-- Settings APIs
local function get_settings(r)
    local err = check_session(r)
    if err then return err end
    
    local d = db.get_db()
    local res = {}
    for row in d:nrows("SELECT * FROM settings") do
        res[row.key] = row.value
    end
    return fm.render("json", res)
end

local function save_settings(r)
    local err = check_session(r)
    if err then return err end
    
    local d = db.get_db()
    for k, v in pairs(r.params) do
        local stmt = d:prepare("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)")
        stmt:bind_values(k, v)
        stmt:step()
        stmt:finalize()
    end
    return fm.render("json", {status = "ok"})
end

-- Schema APIs
local function get_schemas(r)
  local err = check_session(r)
  if err then return err end
  
  local d = db.get_db()
  local res = {}
  for row in d:nrows("SELECT * FROM schemas") do
    table.insert(res, row)
  end
  return fm.render("json", res)
end

local function save_schema(r)
  local err = check_session(r)
  if err then return err end
  
  local name = r.params.name
  local json_schema = r.params.json_schema
  
  local d = db.get_db()
  local old_schema = ""
  local stmt_get = d:prepare("SELECT json_schema, id FROM schemas WHERE name = ?")
  stmt_get:bind_values(name)
  if stmt_get:step() == db.sqlite3.ROW then
      old_schema = stmt_get:get_value(0)
  end
  stmt_get:finalize()

  local stmt = d:prepare("INSERT OR REPLACE INTO schemas (name, json_schema) VALUES (?, ?)")
  stmt:bind_values(name, json_schema)
  stmt:step()
  stmt:finalize()

  local id = d:last_insert_rowid()
  save_history("schema", id, old_schema, json_schema, r.session.username)
  
  return fm.render("json", {status = "ok"})
end

-- Content APIs
local function get_content(r)
  local err = check_session(r)
  if err then return err end
  
  local schema_id = r.params.schema_id
  local lang = r.params.lang or 'en'
  local d = db.get_db()
  local res = {}
  local stmt = d:prepare("SELECT * FROM content WHERE schema_id = ? AND lang = ?")
  stmt:bind_values(schema_id, lang)
  for row in stmt:nrows() do
    table.insert(res, row)
  end
  stmt:finalize()
  return fm.render("json", res)
end

local function save_content(r)
  local err = check_session(r)
  if err then return err end
  
  local schema_id = r.params.schema_id
  local slug = r.params.slug
  local lang = r.params.lang or 'en'
  local data = r.params.data
  local status = r.params.status or 'published'
  
  local d = db.get_db()
  local old_data = ""
  local stmt_get = d:prepare("SELECT data, id FROM content WHERE slug = ? AND lang = ?")
  stmt_get:bind_values(slug, lang)
  if stmt_get:step() == db.sqlite3.ROW then
      old_data = stmt_get:get_value(0)
  end
  stmt_get:finalize()

  local stmt = d:prepare("INSERT OR REPLACE INTO content (schema_id, slug, lang, data, status) VALUES (?, ?, ?, ?, ?)")
  stmt:bind_values(schema_id, slug, lang, data, status)
  stmt:step()
  stmt:finalize()

  local id = d:last_insert_rowid()
  save_history("content", id, old_data, data, r.session.username)
  
  return fm.render("json", {status = "ok"})
end

-- User Management
local function get_users(r)
  local err = check_session(r)
  if err then return err end
  
  local d = db.get_db()
  local res = {}
  for row in d:nrows("SELECT id, username, role FROM users") do
    table.insert(res, row)
  end
  return fm.render("json", res)
end

local function create_user(r)
  local err = check_session(r)
  if err then return err end
  
  local username = r.params.username
  local password = r.params.password
  
  db.add_admin(username, password)
  
  return fm.render("json", {status = "ok"})
end

-- Layout Management
local function get_layouts(r)
  local err = check_session(r)
  if err then return err end
  
  local d = db.get_db()
  local res = {}
  for row in d:nrows("SELECT * FROM layouts") do
    table.insert(res, row)
  end
  return fm.render("json", res)
end

local function save_layout(r)
  local err = check_session(r)
  if err then return err end
  
  local path = r.params.path
  local html = r.params.html
  
  local d = db.get_db()
  local old_html = ""
  local stmt_get = d:prepare("SELECT html, id FROM layouts WHERE path = ?")
  stmt_get:bind_values(path)
  if stmt_get:step() == db.sqlite3.ROW then
      old_html = stmt_get:get_value(0)
  end
  stmt_get:finalize()

  local stmt = d:prepare("INSERT OR REPLACE INTO layouts (path, html) VALUES (?, ?)")
  stmt:bind_values(path, html)
  stmt:step()
  stmt:finalize()

  local id = d:last_insert_rowid()
  save_history("layout", id, old_html, html, r.session.username)
  
  return fm.render("json", {status = "ok"})
end

-- Media Management
local function get_media_list(r)
    local err = check_session(r)
    if err then return err end
    
    local d = db.get_db()
    local res = {}
    for row in d:nrows("SELECT id, filename, mime_type FROM media") do
        table.insert(res, row)
    end
    return fm.render("json", res)
end

local function upload_media(r)
    local err = check_session(r)
    if err then return err end
    
    local file = r.params.file
    if not file then return fm.render("json", {status = "error", message = "No file uploaded"}) end
    
    local filename = file.filename
    local mime_type = file.headers["Content-Type"]
    local data = file.data
    
    local d = db.get_db()
    local stmt = d:prepare("INSERT INTO media (filename, mime_type, data) VALUES (?, ?, ?)")
    stmt:bind_values(filename, mime_type, data)
    stmt:step()
    stmt:finalize()
    
    return fm.render("json", {status = "ok", filename = filename})
end

local function serve_media(r)
    local filename = r.params.filename
    local d = db.get_db()
    local stmt = d:prepare("SELECT mime_type, data FROM media WHERE filename = ?")
    stmt:bind_values(filename)
    if stmt:step() == db.sqlite3.ROW then
        local mime = stmt:get_value(0)
        local data = stmt:get_value(1)
        stmt:finalize()
        return data, {ContentType = mime}
    end
    stmt:finalize()
    return fm.serveError(404)
end

-- History and Settings
local function get_history(r)
    local err = check_session(r)
    if err then return err end
    
    local d = db.get_db()
    local res = {}
    for row in d:nrows("SELECT * FROM history ORDER BY updated_at DESC LIMIT 50") do
        table.insert(res, row)
    end
    return fm.render("json", res)
end

-- Blueprints
local function get_blueprints(r)
    local err = check_session(r)
    if err then return err end
    
    local res = {}
    for k, v in pairs(blueprints) do
        table.insert(res, { id = k, name = v.name, description = v.description })
    end
    return fm.render("json", res)
end

local function apply_blueprint(r)
    local err = check_session(r)
    if err then return err end
    
    local id = r.params.id
    local bp = blueprints[id]
    if not bp then return fm.render("json", {status = "error", message = "Blueprint not found"}) end
    
    local d = db.get_db()
    -- Inject schemas
    for _, s in ipairs(bp.schemas) do
        local stmt = d:prepare("INSERT OR REPLACE INTO schemas (name, json_schema) VALUES (?, ?)")
        stmt:bind_values(s.name, s.json_schema)
        stmt:step()
        stmt:finalize()
    end
    
    -- Inject layouts
    for _, l in ipairs(bp.layouts) do
        local stmt = d:prepare("INSERT OR REPLACE INTO layouts (path, html) VALUES (?, ?)")
        stmt:bind_values(l.path, l.html)
        stmt:step()
        stmt:finalize()
    end
    
    return fm.render("json", {status = "ok"})
end

-- Atomic Persistence
local function persist_db(r)
    local err = check_session(r)
    if err then return err end
    
    local ok = db.persist_to_zip()
    if ok then
        return fm.render("json", {status = "ok", message = "Database successfully baked into atomic binary."})
    else
        return fm.render("json", {status = "error", message = "Persistence failed. Ensure -* flag is active and OS is supported."})
    end
end

local function download_db(r)
    local err = check_session(r)
    if err then return err end
    
    local f = io.open("redcap.db", "rb")
    if f then
        local data = f:read("*all")
        f:close()
        return data, {ContentType = "application/x-sqlite3", ["Content-Disposition"] = "attachment; filename=redcap.db"}
    end
    return fm.serveError(404)
end

local function list_backups(r)
    local err = check_session(r)
    if err then return err end
    
    -- In a real environment, we'd list files in the current dir
    -- Redbean has unix.opendir/readdir
    local backups = {}
    local p = unix.opendir(".")
    if p then
        while true do
            local ent = unix.readdir(p)
            if not ent then break end
            if ent.name:find("%.db%.bak$") then
                table.insert(backups, ent.name)
            end
        end
        unix.closedir(p)
    end
    return fm.render("json", backups)
end

-- Collaborative Presence
local function update_presence(r)
    local err = check_session(r)
    if err then return err end
    
    local d = db.get_db()
    local stmt = d:prepare("INSERT OR REPLACE INTO presence (username, active_tab, item_id, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)")
    stmt:bind_values(r.session.username, r.params.tab, r.params.item_id)
    stmt:step()
    stmt:finalize()
    
    local res = {}
    for row in d:nrows("SELECT * FROM presence WHERE updated_at > datetime('now', '-30 seconds')") do
        table.insert(res, row)
    end
    return fm.render("json", res)
    end

    -- Form Inbox
    local function submit_form(r)

    local schema_name = r.params.schema_name
    local d = db.get_db()
    
    local res = {}
    -- Join with schemas to validate name
    local stmt = d:prepare([[
        SELECT c.* FROM content c 
        JOIN schemas s ON c.schema_id = s.id 
        WHERE s.name = ? AND c.status = 'published'
    ]])
    stmt:bind_values(schema_name)
    for row in stmt:nrows() do
        local data = DecodeJson(row.data)
        data._slug = row.slug
        data._id = row.id
        table.insert(res, data)
    end
    stmt:finalize()
    return fm.render("json", res)
end

local function public_api_single(r)
    local schema_name = r.params.schema_name
    local slug = r.params.slug
    local d = db.get_db()
    
    local stmt = d:prepare([[
        SELECT c.data FROM content c 
        JOIN schemas s ON c.schema_id = s.id 
        WHERE s.name = ? AND c.slug = ? AND c.status = 'published'
    ]])
    stmt:bind_values(schema_name, slug)
    if stmt:step() == sqlite3.ROW then
        local data = DecodeJson(stmt:get_value(0))
        stmt:finalize()
        return fm.render("json", data)
    end
    stmt:finalize()
    return fm.serveError(404)
end

-- Search / Utility
local function find_by_slug(r)
    local err = check_session(r)
    if err then return err end
    
    local slug = r.params.slug
    local d = db.get_db()
    local stmt = d:prepare("SELECT schema_id, status, lang, data FROM content WHERE slug = ?")
    stmt:bind_values(slug)
    if stmt:step() == sqlite3.ROW then
        local res = {
            schema_id = stmt:get_value(0),
            status = stmt:get_value(1),
            lang = stmt:get_value(2),
            data = stmt:get_value(3)
        }
        stmt:finalize()
        return fm.render("json", res)
    end
    stmt:finalize()
    return fm.serveError(404)
end

-- Form Inbox
local function submit_form(r)
    local form_name = r.params.form_name
    local d = db.get_db()
    
    local data = {}
    for k, v in pairs(r.params) do
        if k ~= "form_name" then data[k] = v end
    end
    
    local stmt = d:prepare("INSERT INTO forms (form_name, data) VALUES (?, ?)")
    stmt:bind_values(form_name, EncodeJson(data))
    stmt:step()
    stmt:finalize()
    
    if GetHeader("Referer") then
        return fm.serveRedirect(GetHeader("Referer") .. "?success=1")
    end
    return fm.render("json", {status = "ok"})
end

local function get_forms(r)
    local err = check_session(r)
    if err then return err end
    
    local d = db.get_db()
    local res = {}
    for row in d:nrows("SELECT * FROM forms ORDER BY created_at DESC") do
        table.insert(res, row)
    end
    return fm.render("json", res)
end

-- Static Site Export (SSG)
local function export_static(r)
    local err = check_session(r)
    if err then return err end
    
    local d = db.get_db()
    os.execute("mkdir -p static_export")
    
    -- 1. Export Media
    os.execute("mkdir -p static_export/media")
    for row in d:nrows("SELECT filename, data FROM media") do
        local f = io.open("static_export/media/" .. row.filename, "wb")
        if f then
            f:write(row.data)
            f:close()
        end
    end
    
    -- 2. Export Pages (Exact Layouts)
    for row in d:nrows("SELECT path, html FROM layouts WHERE path != '/*'") do
        local filename = row.path:sub(2)
        if filename == "" then filename = "index" end
        if not filename:find("%.html$") then filename = filename .. ".html" end
        
        -- Create subdirs if needed
        if filename:find("/") then
            local dir = filename:match("(.+)/")
            os.execute("mkdir -p static_export/" .. dir)
        end

        local res = Fetch("http://localhost:" .. GetPort() .. row.path)
        if res then
            local f = io.open("static_export/" .. filename, "w")
            if f then
                f:write(res.body)
                f:close()
            end
        end
    end
    
    -- 3. Export Content (Wildcard Layouts)
    local wild_stmt = d:prepare("SELECT html FROM layouts WHERE path = '/*'")
    if wild_stmt:step() == sqlite3.ROW then
        wild_stmt:finalize()
        for row in d:nrows("SELECT slug, lang FROM content WHERE status = 'published'") do
            local path = "/" .. row.slug .. "?lang=" .. row.lang
            local filename = row.lang .. "/" .. row.slug .. ".html"
            if row.lang == "en" then filename = row.slug .. ".html" end -- Root for default lang
            
            if filename:find("/") then
                local dir = filename:match("(.+)/")
                os.execute("mkdir -p static_export/" .. dir)
            end
            local res = Fetch("http://localhost:" .. GetPort() .. path)
            if res then
                local f = io.open("static_export/" .. filename, "w")
                if f then
                    f:write(res.body)
                    f:close()
                end
            end
        end
    else
        wild_stmt:finalize()
    end
    
    -- 4. ZIP it up
    os.execute("cd static_export && zip -r ../static_site.zip .")
    os.execute("rm -rf static_export")
    
    local f = io.open("static_site.zip", "rb")
    if f then
        local data = f:read("*all")
        f:close()
        os.remove("static_site.zip")
        return data, {ContentType = "application/zip", ["Content-Disposition"] = "attachment; filename=static_site.zip"}
    end
    
    return "Export failed", {status = 500}
end

return {
  login_handler = login_handler,
  dashboard_handler = dashboard_handler,
  get_settings = get_settings,
  save_settings = save_settings,
  get_schemas = get_schemas,
  save_schema = save_schema,
  get_content = get_content,
  save_content = save_content,
  get_users = get_users,
  create_user = create_user,
  get_layouts = get_layouts,
  save_layout = save_layout,
  get_media_list = get_media_list,
  upload_media = upload_media,
  serve_media = serve_media,
  get_history = get_history,
  get_blueprints = get_blueprints,
  apply_blueprint = apply_blueprint,
  persist_db = persist_db,
  update_presence = update_presence,
  public_api_list = public_api_list,
  public_api_single = public_api_single,
  submit_form = submit_form,
  get_forms = get_forms,
  find_by_slug = find_by_slug,
  export_static = export_static,
  download_db = download_db,
  list_backups = list_backups
}
