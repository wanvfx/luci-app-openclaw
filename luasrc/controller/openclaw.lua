-- luci-app-openclaw — LuCI Controller
module("luci.controller.openclaw", package.seeall)

local function sh_quote(v)
	v = tostring(v or "")
	return "'" .. v:gsub("'", "'\\''") .. "'"
end

local function normalize_storage_path(p)
	p = tostring(p or ""):gsub("%s+$", ""):gsub("^%s+", "")
	if p ~= "/" then
		p = p:gsub("/+$", "")
	end
	return p
end

local function is_allowed_storage_path(p)
	p = normalize_storage_path(p)
	if p == "/opt/openclaw" then
		return true
	end
	if p == "" or #p > 220 then
		return false
	end
	if p:find("..", 1, true) then
		return false
	end
	if p:match("[^%w%._%-%+/]") then
		return false
	end
	if p:match("^/mnt/[%w%._%-/]+/openclaw$") or p:match("^/media/[%w%._%-/]+/openclaw$") then
		return true
	end
	return false
end

-- 公共辅助: 获取 OpenClaw 版本号
local function get_openclaw_version()
	local sys = require "luci.sys"
	-- 优先从 package.json 读取版本号 (轻量)，避免每次启动 node 进程
	local dirs = {
		"/opt/openclaw/global/lib/node_modules/openclaw",
		"/opt/openclaw/global/node_modules/openclaw",
	}
	-- pnpm 版本目录
	local pnpm_glob = sys.exec("ls -d /opt/openclaw/global/*/node_modules/openclaw 2>/dev/null"):gsub("%s+$", "")
	for d in pnpm_glob:gmatch("[^\n]+") do
		dirs[#dirs + 1] = d
	end
	for _, d in ipairs(dirs) do
		local pkg = d .. "/package.json"
		local f = io.open(pkg, "r")
		if f then
			local content = f:read("*a")
			f:close()
			local ver = content:match('"version"%s*:%s*"([^"]+)"')
			if ver and ver ~= "" then return ver end
		end
	end
	return ""
end

function index()
	-- 主入口: 服务 → OpenClaw (🧠 作为菜单图标)
	local page = entry({"admin", "services", "openclaw"}, alias("admin", "services", "openclaw", "basic"), _("OpenClaw"), 90)
	page.dependent = false

	-- 基本设置 (CBI)
	entry({"admin", "services", "openclaw", "basic"}, cbi("openclaw/basic"), _("基本设置"), 10).leaf = true

	-- 配置管理 (View — 嵌入 oc-config Web 终端)
	entry({"admin", "services", "openclaw", "advanced"}, template("openclaw/advanced"), _("配置管理"), 20).leaf = true

	-- Web 控制台 (View — 嵌入 OpenClaw Web UI)
	entry({"admin", "services", "openclaw", "console"}, template("openclaw/console"), _("Web 控制台"), 30).leaf = true

	-- 状态 API (AJAX 接口, 供前端 XHR 调用)
	entry({"admin", "services", "openclaw", "status_api"}, call("action_status"), nil).leaf = true

	-- 服务控制 API
	entry({"admin", "services", "openclaw", "service_ctl"}, call("action_service_ctl"), nil).leaf = true

	-- 存储检测 API (安装前可选外置存储)
	entry({"admin", "services", "openclaw", "storage_targets"}, call("action_storage_targets"), nil).leaf = true

	-- 保存安装路径 API
	entry({"admin", "services", "openclaw", "set_storage"}, call("action_set_storage"), nil).leaf = true

	-- 安装/升级日志 API (轮询)
	entry({"admin", "services", "openclaw", "setup_log"}, call("action_setup_log"), nil).leaf = true

	-- 版本检查 API
	entry({"admin", "services", "openclaw", "check_update"}, call("action_check_update"), nil).leaf = true

	-- 执行升级 API
	entry({"admin", "services", "openclaw", "do_update"}, call("action_do_update"), nil).leaf = true

	-- 升级日志 API (轮询)
	entry({"admin", "services", "openclaw", "upgrade_log"}, call("action_upgrade_log"), nil).leaf = true

	-- 卸载运行环境 API
	entry({"admin", "services", "openclaw", "uninstall"}, call("action_uninstall"), nil).leaf = true

	-- 获取网关 Token API (仅认证用户可访问)
	entry({"admin", "services", "openclaw", "get_token"}, call("action_get_token"), nil).leaf = true

	-- 插件升级 API
	entry({"admin", "services", "openclaw", "plugin_upgrade"}, call("action_plugin_upgrade"), nil).leaf = true

	-- 插件升级日志 API (轮询)
	entry({"admin", "services", "openclaw", "plugin_upgrade_log"}, call("action_plugin_upgrade_log"), nil).leaf = true
end

-- ═══════════════════════════════════════════
-- 安装存储目标检测 API
-- ═══════════════════════════════════════════
function action_storage_targets()
	local http = require "luci.http"
	local sys = require "luci.sys"
	local uci = require "luci.model.uci".cursor()

	local function get_avail_kb(path)
		local out = sys.exec("df -kP " .. sh_quote(path) .. " 2>/dev/null | awk 'NR==2{print $4}'"):gsub("%s+", "")
		return tonumber(out) or 0
	end

	local function is_writable(path)
		local ok = sys.exec("[ -w " .. sh_quote(path) .. " ] && echo 1 || echo 0"):gsub("%s+", "")
		return ok == "1"
	end

	local function fstype_of(path)
		local fstype = sys.exec("awk '$2==\"" .. path:gsub("\"", "\\\"") .. "\"{print $3; exit}' /proc/mounts 2>/dev/null"):gsub("%s+", "")
		return fstype ~= "" and fstype or "-"
	end

	local current = normalize_storage_path(uci:get("openclaw", "main", "storage_path") or "/opt/openclaw")
	if not is_allowed_storage_path(current) then
		current = "/opt/openclaw"
	end

	local options = {}
	local seen = {}

	local root_avail_mb = math.floor(get_avail_kb("/opt") / 1024)
	options[#options + 1] = {
		path = "/opt/openclaw",
		label = "系统分区 (/opt/openclaw)",
		mount = "/opt",
		fs = fstype_of("/overlay") ~= "-" and fstype_of("/overlay") or fstype_of("/"),
		available_mb = root_avail_mb,
		recommended = root_avail_mb >= 1536,
		writable = is_writable("/opt"),
		external = false,
	}

	local skip_fs = {
		overlay = true,
		tmpfs = true,
		squashfs = true,
		proc = true,
		sysfs = true,
		devtmpfs = true,
		devpts = true,
		cgroup = true,
		cgroup2 = true,
		pstore = true,
		debugfs = true,
		tracefs = true,
		securityfs = true,
		fusectl = true,
	}

	local mounts = io.open("/proc/mounts", "r")
	if mounts then
		for line in mounts:lines() do
			local dev, mnt, fs = line:match("^(%S+)%s+(%S+)%s+(%S+)%s+")
			if dev and mnt and fs and not skip_fs[fs] then
				if (mnt:match("^/mnt/") or mnt:match("^/media/")) and not seen[mnt] then
					seen[mnt] = true
					local target = mnt .. "/openclaw"
					local avail_mb = math.floor(get_avail_kb(mnt) / 1024)
					options[#options + 1] = {
						path = target,
						label = "外置存储 (" .. mnt .. "/openclaw)",
						mount = mnt,
						fs = fs,
						device = dev,
						available_mb = avail_mb,
						recommended = avail_mb >= 1536,
						writable = is_writable(mnt),
						external = true,
					}
				end
			end
		end
		mounts:close()
	end

	table.sort(options, function(a, b)
		if a.external ~= b.external then
			return a.external
		end
		return (a.available_mb or 0) > (b.available_mb or 0)
	end)

	http.prepare_content("application/json")
	http.write_json({
		status = "ok",
		current = current,
		options = options,
	})
end

-- ═══════════════════════════════════════════
-- 保存安装路径 API
-- ═══════════════════════════════════════════
function action_set_storage()
	local http = require "luci.http"
	local sys = require "luci.sys"
	local uci = require "luci.model.uci".cursor()

	local storage_path = normalize_storage_path(http.formvalue("path") or "")
	if not is_allowed_storage_path(storage_path) then
		http.prepare_content("application/json")
		http.write_json({ status = "error", message = "存储路径无效" })
		return
	end

	if storage_path ~= "/opt/openclaw" then
		local mount_point = storage_path:gsub("/openclaw$", "")
		local mounted = sys.exec("grep -F " .. sh_quote(mount_point) .. " /proc/mounts >/dev/null 2>&1 && echo 1 || echo 0"):gsub("%s+", "")
		if mounted ~= "1" then
			http.prepare_content("application/json")
			http.write_json({ status = "error", message = "外置存储未挂载: " .. mount_point })
			return
		end
		local writable = sys.exec("[ -w " .. sh_quote(mount_point) .. " ] && echo 1 || echo 0"):gsub("%s+", "")
		if writable ~= "1" then
			http.prepare_content("application/json")
			http.write_json({ status = "error", message = "外置存储不可写: " .. mount_point })
			return
		end
	end

	uci:set("openclaw", "main", "storage_path", storage_path)
	uci:commit("openclaw")

	http.prepare_content("application/json")
	http.write_json({ status = "ok", path = storage_path, message = "安装路径已保存" })
end

-- ═══════════════════════════════════════════
-- 状态查询 API: 返回 JSON
-- ═══════════════════════════════════════════
function action_status()
	local http = require "luci.http"
	local sys = require "luci.sys"
	local uci = require "luci.model.uci".cursor()

	local port = uci:get("openclaw", "main", "port") or "18789"
	local pty_port = uci:get("openclaw", "main", "pty_port") or "18793"
	local enabled = uci:get("openclaw", "main", "enabled") or "0"

	-- 验证端口值为纯数字，防止命令注入
	if not port:match("^%d+$") then port = "18789" end
	if not pty_port:match("^%d+$") then pty_port = "18793" end

	local result = {
		enabled = enabled,
		port = port,
		pty_port = pty_port,
		storage_path = uci:get("openclaw", "main", "storage_path") or "/opt/openclaw",
		gateway_running = false,
		gateway_starting = false,
		pty_running = false,
		pid = "",
		memory_kb = 0,
		uptime = "",
		node_version = "",
		openclaw_version = "",
		plugin_version = "",
	}

	-- 插件版本
	local pvf = io.open("/usr/share/openclaw/VERSION", "r")
	if pvf then
		result.plugin_version = pvf:read("*a"):gsub("%s+", "")
		pvf:close()
	end

	-- 检查 Node.js
	local node_bin = "/opt/openclaw/node/bin/node"
	local f = io.open(node_bin, "r")
	if f then
		f:close()
		local node_ver = sys.exec(node_bin .. " --version 2>/dev/null"):gsub("%s+", "")
		result.node_version = node_ver
	end

	-- 检查 OpenClaw 版本
	local oc_ver = get_openclaw_version()
	if oc_ver and oc_ver ~= "" then
		result.openclaw_version = "v" .. oc_ver
	end

	-- 网关端口检查
	local gw_check = sys.exec("netstat -tlnp 2>/dev/null | grep -c ':" .. port .. " ' || echo 0"):gsub("%s+", "")
	result.gateway_running = (tonumber(gw_check) or 0) > 0

	-- 如果端口未监听但 procd 进程存在，说明正在启动中 (gateway 初始化需要数分钟)
	if not result.gateway_running and enabled == "1" then
		local procd_pid = sys.exec("pgrep -f 'openclaw.*gateway' 2>/dev/null | head -1"):gsub("%s+", "")
		if procd_pid ~= "" then
			result.gateway_starting = true
		end
	end

	-- PTY 端口检查
	local pty_check = sys.exec("netstat -tlnp 2>/dev/null | grep -c ':" .. pty_port .. " ' || echo 0"):gsub("%s+", "")
	result.pty_running = (tonumber(pty_check) or 0) > 0

	-- 读取当前活跃模型
	local config_file = "/opt/openclaw/data/.openclaw/openclaw.json"
	local cf = io.open(config_file, "r")
	if cf then
		local content = cf:read("*a")
		cf:close()
		-- 简单正则提取 "primary": "xxx"
		local model = content:match('"primary"%s*:%s*"([^"]+)"')
		if model and model ~= "" then
			result.active_model = model
		end
	end

	-- PID 和内存
	if result.gateway_running then
		local pid = sys.exec("netstat -tlnp 2>/dev/null | awk '/:" .. port .. " /{split($NF,a,\"/\");print a[1];exit}'"):gsub("%s+", "")
		if pid and pid ~= "" then
			result.pid = pid
			-- 内存 (VmRSS from /proc)
			local rss = sys.exec("awk '/VmRSS/{print $2}' /proc/" .. pid .. "/status 2>/dev/null"):gsub("%s+", "")
			result.memory_kb = tonumber(rss) or 0
			-- 运行时间
			local stat_time = sys.exec("stat -c %Y /proc/" .. pid .. " 2>/dev/null"):gsub("%s+", "")
			local start_ts = tonumber(stat_time) or 0
			if start_ts > 0 then
				local uptime_s = os.time() - start_ts
				local hours = math.floor(uptime_s / 3600)
				local mins = math.floor((uptime_s % 3600) / 60)
				local secs = uptime_s % 60
				if hours > 0 then
					result.uptime = string.format("%dh %dm %ds", hours, mins, secs)
				elseif mins > 0 then
					result.uptime = string.format("%dm %ds", mins, secs)
				else
					result.uptime = string.format("%ds", secs)
				end
			end
		end
	end

	http.prepare_content("application/json")
	http.write_json(result)
end

-- ═══════════════════════════════════════════
-- 服务控制 API: start/stop/restart/setup
-- ═══════════════════════════════════════════
function action_service_ctl()
	local http = require "luci.http"
	local sys = require "luci.sys"

	local action = http.formvalue("action") or ""

	if action == "start" then
		sys.exec("/etc/init.d/openclaw start >/dev/null 2>&1 &")
	elseif action == "stop" then
		sys.exec("/etc/init.d/openclaw stop >/dev/null 2>&1")
		-- stop 后额外等待确保端口释放
		sys.exec("sleep 2")
	elseif action == "restart" then
		-- 先完整 stop (确保端口释放)，再后台 start
		sys.exec("/etc/init.d/openclaw stop >/dev/null 2>&1")
		sys.exec("sleep 2")
		sys.exec("/etc/init.d/openclaw start >/dev/null 2>&1 &")
	elseif action == "enable" then
		sys.exec("/etc/init.d/openclaw enable 2>/dev/null")
	elseif action == "disable" then
		sys.exec("/etc/init.d/openclaw disable 2>/dev/null")
	elseif action == "setup" then
		-- 先清理旧日志和状态
		sys.exec("rm -f /tmp/openclaw-setup.log /tmp/openclaw-setup.pid /tmp/openclaw-setup.exit")
		-- 检查 openclaw-env 是否存在
		local env_bin = sys.exec("command -v openclaw-env 2>/dev/null | head -1"):gsub("%s+", "")
		if env_bin == "" then
			local f = io.open("/usr/bin/openclaw-env", "r")
			if f then
				f:close()
				env_bin = "/usr/bin/openclaw-env"
			end
		end
		if env_bin == "" then
			http.prepare_content("application/json")
			http.write_json({ status = "error", message = "未找到 openclaw-env，请重新安装插件后重试。" })
			return
		end
		-- 获取用户选择的版本 (stable=指定版本, latest=最新版)
		local version = http.formvalue("version") or ""
		local env_prefix = ""
		if version == "stable" then
			-- 稳定版: 读取 openclaw-env 中定义的 OC_TESTED_VERSION
			local tested_ver = sys.exec("grep '^OC_TESTED_VERSION=' /usr/bin/openclaw-env 2>/dev/null | cut -d'\"' -f2"):gsub("%s+", "")
			if tested_ver ~= "" then
				env_prefix = "OC_VERSION=" .. tested_ver .. " "
			end
		elseif version ~= "" and version ~= "latest" then
			-- 校验版本号格式 (仅允许数字、点、横线、字母)
			if version:match("^[%d%.%-a-zA-Z]+$") then
				env_prefix = "OC_VERSION=" .. version .. " "
			end
		end
		-- 存储路径选择 (默认 /opt/openclaw，可选 /mnt/*/openclaw)
		local storage_path = normalize_storage_path(http.formvalue("storage_path") or "")
		if storage_path == "" then
			storage_path = normalize_storage_path(require("luci.model.uci").cursor():get("openclaw", "main", "storage_path") or "/opt/openclaw")
		end
		if not is_allowed_storage_path(storage_path) then
			http.prepare_content("application/json")
			http.write_json({ status = "error", message = "存储路径无效: " .. storage_path })
			return
		end

		local storage_cmd = ""
		if storage_path == "/opt/openclaw" then
			storage_cmd = "uci set openclaw.main.storage_path='/opt/openclaw'; uci commit openclaw 2>/dev/null; " ..
				"if [ -L /opt/openclaw ]; then SRC=$(readlink /opt/openclaw 2>/dev/null || true); rm -f /opt/openclaw; mkdir -p /opt/openclaw; [ -n \"$SRC\" ] && [ -d \"$SRC\" ] && cp -a \"$SRC\"/. /opt/openclaw/ 2>/dev/null || true; fi; "
		else
			local mount_point = storage_path:gsub("/openclaw$", "")
			local q_storage = sh_quote(storage_path)
			local q_mount = sh_quote(mount_point)
			storage_cmd =
				"echo '安装存储路径: " .. storage_path .. "' >> /tmp/openclaw-setup.log; " ..
				"grep -F " .. q_mount .. " /proc/mounts >/dev/null 2>&1 || { echo '错误: 外置存储未挂载: " .. mount_point .. "' >> /tmp/openclaw-setup.log; exit 3; }; " ..
				"[ -w " .. q_mount .. " ] || { echo '错误: 外置存储不可写: " .. mount_point .. "' >> /tmp/openclaw-setup.log; exit 4; }; " ..
				"mkdir -p " .. q_storage .. " 2>/dev/null || { echo '错误: 无法创建目录: " .. storage_path .. "' >> /tmp/openclaw-setup.log; exit 5; }; " ..
				"if [ -L /opt/openclaw ]; then CUR=$(readlink /opt/openclaw 2>/dev/null || true); [ \"$CUR\" != " .. q_storage .. " ] && { rm -f /opt/openclaw; ln -s " .. q_storage .. " /opt/openclaw; }; " ..
				"elif [ -d /opt/openclaw ]; then [ \"$(ls -A /opt/openclaw 2>/dev/null)\" != \"\" ] && cp -a /opt/openclaw/. " .. q_storage .. "/ 2>/dev/null || true; rm -rf /opt/openclaw; ln -s " .. q_storage .. " /opt/openclaw; " ..
				"else rm -rf /opt/openclaw 2>/dev/null; ln -s " .. q_storage .. " /opt/openclaw; fi; " ..
				"uci set openclaw.main.storage_path=" .. q_storage .. "; uci commit openclaw 2>/dev/null; "
		end

		-- 后台安装，成功后自动启用并启动服务
		-- 注: openclaw-env 脚本有 set -e，init_openclaw 中的非关键失败不应阻止启动
		sys.exec("( " .. storage_cmd .. env_prefix .. "sh " .. sh_quote(env_bin) .. " setup > /tmp/openclaw-setup.log 2>&1; RC=$?; echo $RC > /tmp/openclaw-setup.exit; if [ $RC -eq 0 ]; then uci set openclaw.main.enabled=1; uci commit openclaw; /etc/init.d/openclaw enable 2>/dev/null; sleep 1; /etc/init.d/openclaw start >> /tmp/openclaw-setup.log 2>&1; fi ) & echo $! > /tmp/openclaw-setup.pid")
		http.prepare_content("application/json")
		http.write_json({ status = "ok", message = "安装已启动，请查看安装日志..." })
		return
	else
		http.prepare_content("application/json")
		http.write_json({ status = "error", message = "未知操作: " .. action })
		return
	end

	http.prepare_content("application/json")
	http.write_json({ status = "ok", action = action })
end

-- ═══════════════════════════════════════════
-- 安装日志轮询 API
-- ═══════════════════════════════════════════
function action_setup_log()
	local http = require "luci.http"
	local sys = require "luci.sys"

	-- 读取日志内容
	local log = ""
	local f = io.open("/tmp/openclaw-setup.log", "r")
	if f then
		log = f:read("*a") or ""
		f:close()
	end

	-- 检查进程是否还在运行
	local running = false
	local pid_file = io.open("/tmp/openclaw-setup.pid", "r")
	if pid_file then
		local pid = pid_file:read("*a"):gsub("%s+", "")
		pid_file:close()
		if pid ~= "" then
			local check = sys.exec("kill -0 " .. pid .. " 2>/dev/null && echo yes || echo no"):gsub("%s+", "")
			running = (check == "yes")
		end
	end

	-- 读取退出码
	local exit_code = -1
	if not running then
		local exit_file = io.open("/tmp/openclaw-setup.exit", "r")
		if exit_file then
			local code = exit_file:read("*a"):gsub("%s+", "")
			exit_file:close()
			exit_code = tonumber(code) or -1
		end
	end

	-- 判断状态
	local state = "idle"
	if running then
		state = "running"
	elseif exit_code == 0 then
		state = "success"
	elseif exit_code > 0 then
		state = "failed"
	end

	http.prepare_content("application/json")
	http.write_json({
		state = state,
		exit_code = exit_code,
		log = log
	})
end

-- ═══════════════════════════════════════════
-- 版本检查 API
-- ═══════════════════════════════════════════
function action_check_update()
	local http = require "luci.http"
	local sys = require "luci.sys"

	-- 当前 OpenClaw 版本
	local current = get_openclaw_version()

	-- 最新 OpenClaw 版本 (从 npm registry 查询)
	local latest = sys.exec("PATH=/opt/openclaw/node/bin:/opt/openclaw/global/bin:$PATH npm view openclaw version 2>/dev/null"):gsub("%s+", "")

	local has_update = false
	if current ~= "" and latest ~= "" and current ~= latest then
		has_update = true
	end

	-- 插件版本检查 (从 GitHub API 获取最新 release tag)
	local plugin_current = ""
	local pf = io.open("/usr/share/openclaw/VERSION", "r")
		or io.open("/root/luci-app-openclaw/VERSION", "r")
	if pf then
		plugin_current = pf:read("*a"):gsub("%s+", "")
		pf:close()
	end

	local plugin_latest = ""
	local plugin_has_update = false
	-- 仅在请求参数含 check_plugin=1 或 quick=1 时检查插件版本
	local check_plugin = http.formvalue("check_plugin") or ""
	local quick = http.formvalue("quick") or ""
	if check_plugin == "1" or quick == "1" then
		-- 使用 GitHub API 获取最新 release tag (轻量, 不下载任何文件)
		local gh_resp = sys.exec("curl -sf --connect-timeout 5 --max-time 10 'https://api.github.com/repos/10000ge10000/luci-app-openclaw/releases/latest' 2>/dev/null | grep -o '\"tag_name\"[[:space:]]*:[[:space:]]*\"[^\"]*\"' | head -1 | cut -d'\"' -f4")
		gh_resp = gh_resp:gsub("%s+", "")
		if gh_resp ~= "" then
			-- tag 可能是 v1.0.3 或 1.0.3
			plugin_latest = gh_resp:gsub("^v", "")
		end
		if plugin_current ~= "" and plugin_latest ~= "" and plugin_current ~= plugin_latest then
			plugin_has_update = true
		end
	end

	http.prepare_content("application/json")
	http.write_json({
		status = "ok",
		current = current,
		latest = latest,
		has_update = has_update,
		plugin_current = plugin_current,
		plugin_latest = plugin_latest,
		plugin_has_update = plugin_has_update
	})
end

-- ═══════════════════════════════════════════
-- 执行升级 API (后台执行 + 日志轮询)
-- ═══════════════════════════════════════════
function action_do_update()
	local http = require "luci.http"
	local sys = require "luci.sys"

	-- 清理旧日志和状态
	sys.exec("rm -f /tmp/openclaw-upgrade.log /tmp/openclaw-upgrade.pid /tmp/openclaw-upgrade.exit")

	-- 后台执行升级，升级完成后自动重启服务
	sys.exec("( sh /usr/bin/openclaw-env upgrade > /tmp/openclaw-upgrade.log 2>&1; RC=$?; echo $RC > /tmp/openclaw-upgrade.exit; if [ $RC -eq 0 ]; then echo '' >> /tmp/openclaw-upgrade.log; echo '正在重启服务...' >> /tmp/openclaw-upgrade.log; /etc/init.d/openclaw restart >> /tmp/openclaw-upgrade.log 2>&1; echo '  [✓] 服务已重启' >> /tmp/openclaw-upgrade.log; fi ) & echo $! > /tmp/openclaw-upgrade.pid")

	http.prepare_content("application/json")
	http.write_json({
		status = "ok",
		message = "升级已在后台启动，请查看升级日志..."
	})
end

-- ═══════════════════════════════════════════
-- 升级日志轮询 API
-- ═══════════════════════════════════════════
function action_upgrade_log()
	local http = require "luci.http"
	local sys = require "luci.sys"

	-- 读取日志内容
	local log = ""
	local f = io.open("/tmp/openclaw-upgrade.log", "r")
	if f then
		log = f:read("*a") or ""
		f:close()
	end

	-- 检查进程是否还在运行
	local running = false
	local pid_file = io.open("/tmp/openclaw-upgrade.pid", "r")
	if pid_file then
		local pid = pid_file:read("*a"):gsub("%s+", "")
		pid_file:close()
		if pid ~= "" then
			local check = sys.exec("kill -0 " .. pid .. " 2>/dev/null && echo yes || echo no"):gsub("%s+", "")
			running = (check == "yes")
		end
	end

	-- 读取退出码
	local exit_code = -1
	if not running then
		local exit_file = io.open("/tmp/openclaw-upgrade.exit", "r")
		if exit_file then
			local code = exit_file:read("*a"):gsub("%s+", "")
			exit_file:close()
			exit_code = tonumber(code) or -1
		end
	end

	-- 判断状态
	local state = "idle"
	if running then
		state = "running"
	elseif exit_code == 0 then
		state = "success"
	elseif exit_code > 0 then
		state = "failed"
	end

	http.prepare_content("application/json")
	http.write_json({
		state = state,
		exit_code = exit_code,
		log = log
	})
end

-- ═══════════════════════════════════════════
-- 卸载运行环境 API
-- ═══════════════════════════════════════════
function action_uninstall()
	local http = require "luci.http"
	local sys = require "luci.sys"

	-- 停止服务
	sys.exec("/etc/init.d/openclaw stop >/dev/null 2>&1")
	-- 禁用开机启动
	sys.exec("/etc/init.d/openclaw disable 2>/dev/null")
	-- 设置 UCI enabled=0
	sys.exec("uci set openclaw.main.enabled=0; uci commit openclaw 2>/dev/null")
	-- 删除 Node.js + OpenClaw 运行环境
	sys.exec("rm -rf /opt/openclaw")
	-- 清理临时文件
	sys.exec("rm -f /tmp/openclaw-setup.* /tmp/openclaw-update.log /var/run/openclaw*.pid")
	-- 删除 openclaw 系统用户
	sys.exec("sed -i '/^openclaw:/d' /etc/passwd /etc/shadow /etc/group 2>/dev/null")

	http.prepare_content("application/json")
	http.write_json({
		status = "ok",
		message = "运行环境已卸载。Node.js、OpenClaw 及相关数据已清理。"
	})
end

-- ═══════════════════════════════════════════
-- 获取 Token API
-- 仅通过 LuCI 认证后可调用，避免 Token 嵌入 HTML 源码
-- 返回网关 Token 和 PTY Token
-- ═══════════════════════════════════════════
function action_get_token()
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()
	local token = uci:get("openclaw", "main", "token") or ""
	local pty_token = uci:get("openclaw", "main", "pty_token") or ""
	http.prepare_content("application/json")
	http.write_json({ token = token, pty_token = pty_token })
end

-- ═══════════════════════════════════════════
-- 插件升级 API (后台下载 .run 并执行)
-- 参数: version — 目标版本号 (如 1.0.8)
-- ═══════════════════════════════════════════
function action_plugin_upgrade()
	local http = require "luci.http"
	local sys = require "luci.sys"

	local version = http.formvalue("version") or ""
	if version == "" then
		http.prepare_content("application/json")
		http.write_json({ status = "error", message = "缺少版本号参数" })
		return
	end

	-- 安全检查: version 只允许数字和点
	if not version:match("^[%d%.]+$") then
		http.prepare_content("application/json")
		http.write_json({ status = "error", message = "版本号格式无效" })
		return
	end

	-- 清理旧日志和状态
	sys.exec("rm -f /tmp/openclaw-plugin-upgrade.log /tmp/openclaw-plugin-upgrade.pid /tmp/openclaw-plugin-upgrade.exit")

	-- 后台执行: 下载 .run 并执行安装
	local run_url = "https://github.com/10000ge10000/luci-app-openclaw/releases/download/v" .. version .. "/luci-app-openclaw_" .. version .. ".run"
	-- 使用 curl 下载 (-L 跟随重定向), 然后 sh 执行
	sys.exec(string.format(
		"( echo '正在下载插件 v%s ...' > /tmp/openclaw-plugin-upgrade.log; " ..
		"curl -sL --connect-timeout 15 --max-time 120 -o /tmp/luci-app-openclaw-update.run '%s' >> /tmp/openclaw-plugin-upgrade.log 2>&1; " ..
		"RC=$?; " ..
		"if [ $RC -ne 0 ]; then " ..
		"  echo '下载失败 (curl exit: '$RC')' >> /tmp/openclaw-plugin-upgrade.log; " ..
		"  echo '如果无法访问 GitHub，请手动下载: %s' >> /tmp/openclaw-plugin-upgrade.log; " ..
		"  echo $RC > /tmp/openclaw-plugin-upgrade.exit; " ..
		"else " ..
		"  FSIZE=$(wc -c < /tmp/luci-app-openclaw-update.run 2>/dev/null | tr -d ' '); " ..
		"  echo \"下载完成 (${FSIZE} bytes)\" >> /tmp/openclaw-plugin-upgrade.log; " ..
		"  if [ \"$FSIZE\" -lt 10000 ] 2>/dev/null; then " ..
		"    echo '文件过小，可能下载失败或链接无效' >> /tmp/openclaw-plugin-upgrade.log; " ..
		"    echo 1 > /tmp/openclaw-plugin-upgrade.exit; " ..
		"  else " ..
		"    echo '' >> /tmp/openclaw-plugin-upgrade.log; " ..
		"    echo '正在安装...' >> /tmp/openclaw-plugin-upgrade.log; " ..
		"    sh /tmp/luci-app-openclaw-update.run >> /tmp/openclaw-plugin-upgrade.log 2>&1; " ..
		"    RC2=$?; echo $RC2 > /tmp/openclaw-plugin-upgrade.exit; " ..
		"    if [ $RC2 -eq 0 ]; then " ..
		"      echo '' >> /tmp/openclaw-plugin-upgrade.log; " ..
		"      echo '✅ 插件升级完成！请刷新浏览器页面。' >> /tmp/openclaw-plugin-upgrade.log; " ..
		"    else " ..
		"      echo '安装执行失败 (exit: '$RC2')' >> /tmp/openclaw-plugin-upgrade.log; " ..
		"    fi; " ..
		"  fi; " ..
		"  rm -f /tmp/luci-app-openclaw-update.run; " ..
		"fi " ..
		") & echo $! > /tmp/openclaw-plugin-upgrade.pid",
		version, run_url, run_url
	))

	http.prepare_content("application/json")
	http.write_json({
		status = "ok",
		message = "插件升级已在后台启动..."
	})
end

-- ═══════════════════════════════════════════
-- 插件升级日志轮询 API
-- ═══════════════════════════════════════════
function action_plugin_upgrade_log()
	local http = require "luci.http"
	local sys = require "luci.sys"

	local log = ""
	local f = io.open("/tmp/openclaw-plugin-upgrade.log", "r")
	if f then
		log = f:read("*a") or ""
		f:close()
	end

	local running = false
	local pid_file = io.open("/tmp/openclaw-plugin-upgrade.pid", "r")
	if pid_file then
		local pid = pid_file:read("*a"):gsub("%s+", "")
		pid_file:close()
		if pid ~= "" then
			local check = sys.exec("kill -0 " .. pid .. " 2>/dev/null && echo yes || echo no"):gsub("%s+", "")
			running = (check == "yes")
		end
	end

	local exit_code = -1
	if not running then
		local exit_file = io.open("/tmp/openclaw-plugin-upgrade.exit", "r")
		if exit_file then
			local code = exit_file:read("*a"):gsub("%s+", "")
			exit_file:close()
			exit_code = tonumber(code) or -1
		end
	end

	local state = "idle"
	if running then
		state = "running"
	elseif exit_code == 0 then
		state = "success"
	elseif exit_code > 0 then
		state = "failed"
	end

	http.prepare_content("application/json")
	http.write_json({
		status = "ok",
		log = log,
		state = state,
		running = running,
		exit_code = exit_code
	})
end
