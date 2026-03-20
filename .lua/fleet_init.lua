fm = require "fullmoon"
local sqlite3 = require "lsqlite3"

-- Fleet Database
local fdb = sqlite3.open("fleet.db")
fdb:busy_timeout(1000)
fdb:exec[[
    CREATE TABLE IF NOT EXISTS sites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        domain TEXT UNIQUE NOT NULL,
        port INTEGER UNIQUE NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS fleet_users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL
    );
]]

local function check_session(r)
    if not r.session.username then
        return fm.serveRedirect("/fleet/login")
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

local function get_next_port()
    local stmt = fdb:prepare("SELECT MAX(port) FROM sites")
    if stmt:step() == sqlite3.ROW then
        local max = stmt:get_value(0)
        stmt:finalize()
        return (max or 8000) + 1
    end
    stmt:finalize()
    return 8001
end

-- SEC-01: Parameter Sanitization
local function is_valid_name(s)
    return s and s:match("^[a-z0-9%-]+$") ~= nil
end

local function is_valid_domain(s)
    return s and s:match("^[a-z0-9%.%-]+$") ~= nil
end

-- Management APIs
local function list_sites(r)
    local err = check_session(r)
    if err then return err end
    
    local res = {}
    for row in fdb:nrows("SELECT * FROM sites") do
        table.insert(res, row)
    end
    return fm.render("json", res)
end

local function create_site(r)
    local err = check_session(r)
    if err then return err end
    
    local name = r.params.name
    local domain = r.params.domain
    
    -- SEC-01 Mitigation
    if not is_valid_name(name) or not is_valid_domain(domain) then
        return fm.render("json", {status = "error", message = "Invalid name or domain format"})
    end
    
    local port = get_next_port()
    local filename = "sites/" .. name .. ".com"
    os.execute("mkdir -p sites")
    
    -- Clone atomic binary
    os.execute(string.format("cp redcap.com %q", filename))
    
    -- Generate Systemd Service
    local service_content = string.format([[
[Unit]
Description=Redcap CMS - %s
After=network.target

[Service]
Type=simple
ExecStart=%s/%s -p %d -*
Restart=always
User=root

[Install]
WantedBy=multi-user.target
]], name, ProgramDirectory(), filename, port)

    local sf = io.open("sites/" .. name .. ".service", "w")
    if sf then
        sf:write(service_content)
        sf:close()
    end
    
    -- Record in DB
    local stmt = fdb:prepare("INSERT INTO sites (name, domain, port) VALUES (?, ?, ?)")
    stmt:bind_values(name, domain, port)
    stmt:step()
    stmt:finalize()
    
    -- Start via simple background for prototype (user should install systemd in production)
    local cmd = string.format("./%q -p %d -* > %q 2>&1 &", filename, port, "sites/" .. name .. ".log")
    os.execute(cmd)
    
    return fm.render("json", {status = "ok", port = port, message = "Site deployed. Install sites/" .. name .. ".service for auto-start."})
end

local function generate_nginx(r)
    local err = check_session(r)
    if err then return err end
    
    local conf = ""
    for row in fdb:nrows("SELECT * FROM sites") do
        conf = conf .. string.format([[
server {
    listen 80;
    server_name %s;
    location / {
        proxy_pass http://127.0.0.1:%d;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
]], row.domain, row.port)
    end
    return conf, {ContentType = "text/plain"}
end

-- SEC-04: Fleet Auth
local function login_handler(r)
    local username = r.params.username
    local password = r.params.password
    
    local stmt = fdb:prepare("SELECT password_hash FROM fleet_users WHERE username = ?")
    stmt:bind_values(username)
    if stmt:step() == sqlite3.ROW then
        local hash = stmt:get_value(0)
        local argon2 = require "argon2"
        if argon2.verify(hash, password) then
            r.session.username = username
            return fm.render("json", {status = "ok"})
        end
    end
    stmt:finalize()
    return fm.render("json", {status = "error", message = "Invalid credentials"})
end

-- Bootstrap Fleet Admin
local function bootstrap_fleet()
    local count = 0
    for _ in fdb:nrows("SELECT 1 FROM fleet_users") do count = count + 1 end
    if count == 0 then
        local argon2 = require "argon2"
        local hash = argon2.hash_encoded("fleetadmin", GetRandomBytes(16))
        local stmt = fdb:prepare("INSERT INTO fleet_users (username, password_hash) VALUES ('admin', ?)")
        stmt:bind_values(hash)
        stmt:step()
        stmt:finalize()
        print("Fleet Provisioner initialized with default user 'admin' and password 'fleetadmin'")
    end
end

bootstrap_fleet()

-- Global security headers
local function with_security(handler)
    return function(r)
        SetHeader("Content-Security-Policy", "default-src 'self' 'unsafe-inline' unpkg.com; img-src 'self' data:;")
        SetHeader("X-Frame-Options", "DENY")
        SetHeader("X-Content-Type-Options", "nosniff")
        SetHeader("X-XSS-Protection", "1; mode=block")
        return handler(r)
    end
end

fm.setRoute("/fleet/login", with_security(fm.serveAsset("/fleet/login.html")))
fm.setRoute("/fleet/api/login", {method = "POST"}, with_security(login_handler))
fm.setRoute("/fleet/api/sites", with_security(list_sites))
fm.setRoute({"/fleet/api/sites", method = "POST"}, with_security(create_site))
fm.setRoute("/fleet/api/nginx", with_security(generate_nginx))

-- Root redirects to dashboard
fm.setRoute("/", with_security(function(r)
    return fm.serveRedirect("/fleet/index.html")
end))

fm.setRoute("/fleet/index.html", with_security(fm.serveAsset("/fleet/index.html")))

fm.run()
