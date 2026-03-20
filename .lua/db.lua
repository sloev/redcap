local sqlite3 = require "lsqlite3"

local DB_NAME = "redcap.db"
local DB_PATH = DB_NAME 
local INTERNAL_PATH = "/zip/" .. DB_NAME

db = nil

local function SetupSql()
    if db then return db end
    db = sqlite3.open(DB_PATH)
    db:busy_timeout(1000)
    db:exec[[PRAGMA journal_mode=WAL]]
    db:exec[[PRAGMA synchronous=NORMAL]]
    return db
end

local function run_integrity_check()
    local d = SetupSql()
    for row in d:nrows("PRAGMA integrity_check") do
        if row.integrity_check ~= "ok" then
            Log(kLogError, "Database integrity check failed: " .. row.integrity_check)
            return false
        end
    end
    Log(kLogInfo, "Database integrity check passed.")
    return true
end

local function perform_backup()
    local d = SetupSql()
    -- Check when last backup was performed via settings
    local last_backup = 0
    local stmt = d:prepare("SELECT value FROM settings WHERE key = 'last_backup_at'")
    if stmt and stmt:step() == sqlite3.ROW then
        last_backup = tonumber(stmt:get_value(0)) or 0
    end
    if stmt then stmt:finalize() end

    local now = os.time()
    if now - last_backup > 86400 then -- 24 hours
        d:close()
        db = nil
        -- Simple file copy for backup
        local f_in = io.open(DB_PATH, "rb")
        if f_in then
            local data = f_in:read("*all")
            f_in:close()
            local f_out = io.open(DB_PATH .. ".bak", "wb")
            if f_out then
                f_out:write(data)
                f_out:close()
                Log(kLogInfo, "Daily backup created: " .. DB_PATH .. ".bak")
                
                -- Record backup time
                local d2 = SetupSql()
                local stmt_set = d2:prepare("INSERT OR REPLACE INTO settings (key, value) VALUES ('last_backup_at', ?)")
                stmt_set:bind_values(tostring(now))
                stmt_set:step()
                stmt_set:finalize()
            end
        end
    end
end

local function init_schema()
    local d = SetupSql()
    d:exec[[
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'admin'
        );

        CREATE TABLE IF NOT EXISTS schemas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            json_schema TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS content (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            schema_id INTEGER NOT NULL,
            slug TEXT NOT NULL,
            lang TEXT NOT NULL DEFAULT 'en',
            data TEXT NOT NULL,
            metadata TEXT,
            status TEXT NOT NULL DEFAULT 'published',
            UNIQUE(slug, lang),
            FOREIGN KEY(schema_id) REFERENCES schemas(id)
        );

        CREATE TABLE IF NOT EXISTS media (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filename TEXT UNIQUE NOT NULL,
            mime_type TEXT NOT NULL,
            data BLOB NOT NULL
        );

        CREATE TABLE IF NOT EXISTS layouts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT UNIQUE NOT NULL,
            html TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_type TEXT NOT NULL,
            item_id INTEGER NOT NULL,
            old_value TEXT,
            new_value TEXT NOT NULL,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_by TEXT
        );

        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT
        );

        CREATE TABLE IF NOT EXISTS presence (
            username TEXT PRIMARY KEY,
            active_tab TEXT,
            item_id TEXT,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS forms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            form_name TEXT NOT NULL,
            data TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
    ]]
    
    local has_status = false
    for row in d:nrows("PRAGMA table_info(content)") do
        if row.name == "status" then has_status = true end
    end
    if not has_status then
        d:exec("ALTER TABLE content ADD COLUMN status TEXT NOT NULL DEFAULT 'published'")
    end

    local has_lang = false
    for row in d:nrows("PRAGMA table_info(content)") do
        if row.name == "lang" then has_lang = true end
    end
    if not has_lang then
        d:exec("ALTER TABLE content ADD COLUMN lang TEXT NOT NULL DEFAULT 'en'")
    end
end

local function add_admin(username, password)
    local d = SetupSql()
    local argon2 = require "argon2"
    local salt = GetRandomBytes(16)
    local hash = argon2.hash_encoded(password, salt)
    local stmt = d:prepare("INSERT OR REPLACE INTO users (username, password_hash, role) VALUES (?, ?, 'admin')")
    stmt:bind_values(username, hash)
    stmt:step()
    stmt:finalize()
end

local function persist_to_zip()
    if not StoreAsset then return false end
    if db then db:close(); db = nil end
    local f = io.open(DB_PATH, "rb")
    if f then
        local blob = f:read("*all")
        f:close()
        local ok, err = pcall(StoreAsset, "/" .. DB_NAME, blob)
        return ok
    end
    return false
end

local function bootstrap_from_zip()
    local zip_file = io.open(INTERNAL_PATH, "rb")
    if zip_file then
        local data = zip_file:read("*all")
        zip_file:close()
        local local_test = io.open(DB_PATH, "rb")
        if not local_test then
            local local_file = io.open(DB_PATH, "wb")
            local_file:write(data)
            local_file:close()
        else
            local_test:close()
        end
    end
end

return {
    get_db = SetupSql,
    sqlite3 = sqlite3,
    init_schema = init_schema,
    add_admin = add_admin,
    persist_to_zip = persist_to_zip,
    bootstrap_from_zip = bootstrap_from_zip,
    run_integrity_check = run_integrity_check,
    perform_backup = perform_backup
}
