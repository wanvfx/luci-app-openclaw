-- luci-app-openclaw — 基本设置 CBI Model
local sys = require "luci.sys"

m = Map("openclaw", "OpenClaw AI 网关",
	"OpenClaw 是一个 AI 编程代理网关，支持 GitHub Copilot、Claude、GPT、Gemini 等大模型以及 Telegram、Discord 等多种消息渠道。")

-- 隐藏底部的「保存并应用」「保存」「复位」按钮 (本页无可编辑的 UCI 选项)
m.pageaction = false

-- ═══════════════════════════════════════════
-- 状态面板
-- ═══════════════════════════════════════════
s1 = m:section(SimpleSection, nil)
s1.template = "cbi/nullsection"

status = s1:option(DummyValue, "_status_panel")
status.rawhtml = true
status.cfgvalue = function(self, section)
	local status_url = luci.dispatcher.build_url("admin", "services", "openclaw", "status_api")
	local html = {}
	html[#html+1] = '<style type="text/css">'
	html[#html+1] = '#oc-status-panel{margin:0 0 20px 0;padding:0;border:1px solid #e0e0e0;border-radius:8px;background:#fff;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,0.06);}';
	html[#html+1] = '#oc-status-panel .panel-title{background:linear-gradient(135deg,#4a90d9,#357abd);color:#fff;padding:10px 16px;font-size:14px;font-weight:600;letter-spacing:.5px;}';
	html[#html+1] = '#oc-status-panel table{width:100%;border-collapse:collapse;}';
	html[#html+1] = '#oc-status-panel td{padding:8px 16px;border-bottom:1px solid #f2f2f2;font-size:13px;vertical-align:middle;}';
	html[#html+1] = '#oc-status-panel tr:last-child td{border-bottom:none;}';
	html[#html+1] = '#oc-status-panel td:first-child{width:120px;color:#888;font-weight:500;white-space:nowrap;}';
	html[#html+1] = '#oc-status-panel td:last-child{color:#333;}';
	html[#html+1] = '.oc-badge{display:inline-block;padding:2px 12px;border-radius:12px;font-size:12px;font-weight:600;}';
	html[#html+1] = '.oc-badge-running{background:#e6f7e9;color:#1a7f37;}.oc-badge-stopped{background:#ffeef0;color:#cf222e;}.oc-badge-starting{background:#fff8c5;color:#9a6700;}.oc-badge-disabled{background:#f0f0f0;color:#656d76;}.oc-badge-unknown{background:#fff8c5;color:#9a6700;}';
	html[#html+1] = '.oc-dot{display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:6px;vertical-align:middle;}.oc-dot-green{background:#1a7f37;}.oc-dot-red{background:#cf222e;}.oc-dot-gray{background:#999;}';
	html[#html+1] = '</style>'
	html[#html+1] = '<div id="oc-status-panel"><div class="panel-title">🦞 OpenClaw 服务状态</div><div class="panel-body"><table>'
	html[#html+1] = '<tr><td>运行状态</td><td id="oc-st-status"><span class="oc-badge oc-badge-unknown">加载中...</span></td></tr>'
	html[#html+1] = '<tr><td>网关服务</td><td id="oc-st-gateway">-</td></tr>'
	html[#html+1] = '<tr><td>配置终端</td><td id="oc-st-pty">-</td></tr>'
	html[#html+1] = '<tr><td>活跃模型</td><td id="oc-st-model">-</td></tr>'
	html[#html+1] = '<tr><td>进程 PID</td><td id="oc-st-pid">-</td></tr>'
	html[#html+1] = '<tr><td>内存占用</td><td id="oc-st-mem">-</td></tr>'
	html[#html+1] = '<tr><td>运行时间</td><td id="oc-st-uptime">-</td></tr>'
	html[#html+1] = '<tr><td>Node.js</td><td id="oc-st-node">-</td></tr>'
	html[#html+1] = '<tr><td>安装路径</td><td id="oc-st-storage">-</td></tr>'
	html[#html+1] = '<tr><td>OpenClaw</td><td id="oc-st-ocver">-</td></tr>'
	html[#html+1] = '<tr><td>插件版本</td><td id="oc-st-plugin">-</td></tr>'
	html[#html+1] = '</table></div></div>'
	html[#html+1] = '<script type="text/javascript">'
	html[#html+1] = '(function(){var statusUrl="' .. status_url .. '";'
	html[#html+1] = 'function updateStatus(){(new XHR()).get(statusUrl,null,function(x){try{var d=JSON.parse(x.responseText);'
	html[#html+1] = 'var stEl=document.getElementById("oc-st-status");if(d.enabled!=="1"){stEl.innerHTML="<span class=\\"oc-badge oc-badge-disabled\\">已禁用</span>";}else if(d.gateway_running){stEl.innerHTML="<span class=\\"oc-badge oc-badge-running\\">运行中</span>";}else if(d.gateway_starting){stEl.innerHTML="<span class=\\"oc-badge oc-badge-starting\\">⏳ 正在启动...</span>";}else{stEl.innerHTML="<span class=\\"oc-badge oc-badge-stopped\\">已停止</span>";}'
	html[#html+1] = 'var gwEl=document.getElementById("oc-st-gateway");if(d.gateway_running){gwEl.innerHTML="<span class=\\"oc-dot oc-dot-green\\"></span>监听中 :"+d.port;}else if(d.gateway_starting){gwEl.innerHTML="<span class=\\"oc-dot oc-dot-gray\\"></span>初始化中，首次启动可能需要 2~5 分钟...";}else{gwEl.innerHTML="<span class=\\"oc-dot oc-dot-red\\"></span>未监听";}'
	html[#html+1] = 'var ptyEl=document.getElementById("oc-st-pty");if(d.pty_running){ptyEl.innerHTML="<span class=\\"oc-dot oc-dot-green\\"></span>监听中 :"+d.pty_port;}else{ptyEl.innerHTML="<span class=\\"oc-dot oc-dot-gray\\"></span>未监听";}'
	html[#html+1] = 'document.getElementById("oc-st-pid").textContent=d.pid||"-";var modelEl=document.getElementById("oc-st-model");if(d.active_model){modelEl.innerHTML="<code style=\\"padding:2px 8px;background:#f0f3f6;border-radius:4px;font-size:12px;\\">"+d.active_model+"</code>";}else{modelEl.textContent="未配置";}'
	html[#html+1] = 'var memEl=document.getElementById("oc-st-mem");if(d.memory_kb>0){memEl.textContent=(d.memory_kb/1024).toFixed(1)+" MB";}else{memEl.textContent="-";}'
	html[#html+1] = 'document.getElementById("oc-st-uptime").textContent=d.uptime||"-";document.getElementById("oc-st-node").textContent=d.node_version||"未安装";document.getElementById("oc-st-storage").textContent=d.storage_path||"/opt/openclaw";document.getElementById("oc-st-ocver").textContent=d.openclaw_version||"未安装";document.getElementById("oc-st-plugin").textContent=d.plugin_version?("v"+d.plugin_version):"-";'
	html[#html+1] = '}catch(e){var xel=document.getElementById("oc-st-status");if(xel)xel.innerHTML="<span class=\\"oc-badge oc-badge-unknown\\">查询失败</span>";}});}updateStatus();setInterval(updateStatus,5000);}());'
	html[#html+1] = '</script>'
	return table.concat(html, "\n")
end

-- ═══════════════════════════════════════════
-- 快捷操作
-- ═══════════════════════════════════════════
s3 = m:section(SimpleSection, nil, "快捷操作")
s3.template = "cbi/nullsection"

act = s3:option(DummyValue, "_actions")
act.rawhtml = true
act.cfgvalue = function(self, section)
	local ctl_url = luci.dispatcher.build_url("admin", "services", "openclaw", "service_ctl")
	local log_url = luci.dispatcher.build_url("admin", "services", "openclaw", "setup_log")
	local check_url = luci.dispatcher.build_url("admin", "services", "openclaw", "check_update")
	local update_url = luci.dispatcher.build_url("admin", "services", "openclaw", "do_update")
	local upgrade_log_url = luci.dispatcher.build_url("admin", "services", "openclaw", "upgrade_log")
	local uninstall_url = luci.dispatcher.build_url("admin", "services", "openclaw", "uninstall")
	local set_storage_url = luci.dispatcher.build_url("admin", "services", "openclaw", "set_storage")
	local plugin_upgrade_url = luci.dispatcher.build_url("admin", "services", "openclaw", "plugin_upgrade")
	local plugin_upgrade_log_url = luci.dispatcher.build_url("admin", "services", "openclaw", "plugin_upgrade_log")
	local storage_url = luci.dispatcher.build_url("admin", "services", "openclaw", "storage_targets")
	local html = {}

	-- 按钮区域
	html[#html+1] = '<div style="display:flex;gap:10px;flex-wrap:wrap;margin:10px 0;">'
	html[#html+1] = '<button class="btn cbi-button cbi-button-apply" type="button" onclick="ocShowSetupDialog()" id="btn-setup" title="下载 Node.js 并安装 OpenClaw">📦 安装运行环境</button>'
	html[#html+1] = '<button class="btn cbi-button cbi-button-action" type="button" onclick="ocServiceCtl(\'restart\')">🔄 重启服务</button>'
	html[#html+1] = '<button class="btn cbi-button cbi-button-action" type="button" onclick="ocServiceCtl(\'stop\')">⏹️ 停止服务</button>'
	html[#html+1] = '<span style="position:relative;display:inline-block;" id="btn-check-update-wrap"><button class="btn cbi-button cbi-button-action" type="button" onclick="ocCheckUpdate()" id="btn-check-update">🔍 检测升级</button><span id="update-dot" style="display:none;position:absolute;top:-2px;right:-2px;width:10px;height:10px;background:#e36209;border-radius:50%;border:2px solid #fff;box-shadow:0 0 0 1px #e36209;"></span></span>'
	html[#html+1] = '<button class="btn cbi-button cbi-button-remove" type="button" onclick="ocUninstall()" id="btn-uninstall" title="删除 Node.js、OpenClaw 运行环境及相关数据">🗑️ 卸载环境</button>'
	html[#html+1] = '</div>'
	html[#html+1] = '<div id="action-result" style="margin-top:8px;"></div>'
	html[#html+1] = '<div id="oc-update-action" style="margin-top:8px;display:none;"></div>'
	html[#html+1] = '<div style="margin-top:10px;padding:10px 12px;border:1px solid #d8dee4;border-radius:6px;background:#fafbfc;display:flex;align-items:center;gap:10px;flex-wrap:wrap;">'
	html[#html+1] = '<span style="font-size:13px;color:#444;font-weight:600;">安装路径：</span>'
	html[#html+1] = '<select id="oc-storage-select-main" style="min-width:280px;padding:6px 8px;border:1px solid #d0d7de;border-radius:4px;background:#fff;"><option value="/opt/openclaw">/opt/openclaw</option></select>'
	html[#html+1] = '<button class="btn cbi-button cbi-button-action" type="button" onclick="ocSaveStoragePath()" id="btn-save-storage">💾 保存路径</button>'
	html[#html+1] = '<span id="oc-storage-main-tip" style="font-size:12px;color:#666;"></span>'
	html[#html+1] = '</div>'

	-- 版本选择对话框 (默认隐藏)
	html[#html+1] = '<div id="oc-setup-dialog" style="display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:10000;align-items:center;justify-content:center;">'
	html[#html+1] = '<div style="background:#fff;border-radius:12px;padding:24px 28px;max-width:480px;width:90%;box-shadow:0 8px 32px rgba(0,0,0,0.2);">'
	html[#html+1] = '<h3 style="margin:0 0 16px 0;font-size:16px;color:#333;">📦 选择安装版本</h3>'
	html[#html+1] = '<div style="display:flex;flex-direction:column;gap:12px;">'
	-- 稳定版选项
	html[#html+1] = '<label style="display:flex;align-items:flex-start;gap:10px;padding:14px 16px;border:2px solid #4a90d9;border-radius:8px;cursor:pointer;background:#f0f7ff;" id="oc-opt-stable">'
	html[#html+1] = '<input type="radio" name="oc-ver-choice" value="stable" checked style="margin-top:2px;">'
	html[#html+1] = '<div><strong style="color:#333;">✅ 稳定版 (推荐)</strong>'
	html[#html+1] = '<div style="font-size:12px;color:#666;margin-top:4px;">版本 v' .. luci.sys.exec("sed -n 's/^OC_TESTED_VERSION=\"\\(.*\\)\"/\\1/p' /usr/bin/openclaw-env 2>/dev/null"):gsub("%s+", "") .. '，已经过完整测试，兼容性良好。</div>'
	html[#html+1] = '</div></label>'
	-- 最新版选项
	html[#html+1] = '<label style="display:flex;align-items:flex-start;gap:10px;padding:14px 16px;border:2px solid #e0e0e0;border-radius:8px;cursor:pointer;background:#fff;" id="oc-opt-latest">'
	html[#html+1] = '<input type="radio" name="oc-ver-choice" value="latest" style="margin-top:2px;">'
	html[#html+1] = '<div><strong style="color:#333;">🆕 最新版</strong>'
	html[#html+1] = '<div style="font-size:12px;color:#e36209;margin-top:4px;">⚠️ 安装 npm 上的最新发布版本，可能存在未经验证的兼容性问题。</div>'
	html[#html+1] = '</div></label>'
	html[#html+1] = '</div>'
	-- 按钮区
	html[#html+1] = '<div style="display:flex;gap:10px;justify-content:flex-end;margin-top:20px;">'
	html[#html+1] = '<button class="btn cbi-button" type="button" onclick="ocCloseSetupDialog()" style="min-width:80px;">取消</button>'
	html[#html+1] = '<button class="btn cbi-button cbi-button-apply" type="button" onclick="ocConfirmSetup()" style="min-width:80px;">开始安装</button>'
	html[#html+1] = '</div>'
	html[#html+1] = '</div></div>'

	-- 安装日志面板 (默认隐藏)
	html[#html+1] = '<div id="setup-log-panel" style="display:none;margin-top:12px;">'
	html[#html+1] = '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px;">'
	html[#html+1] = '<span id="setup-log-title" style="font-weight:600;font-size:14px;">📋 安装日志</span>'
	html[#html+1] = '<span id="setup-log-status" style="font-size:12px;color:#999;"></span>'
	html[#html+1] = '</div>'
	html[#html+1] = '<pre id="setup-log-content" style="background:#1a1b26;color:#a9b1d6;padding:14px 16px;border-radius:6px;font-size:12px;line-height:1.6;max-height:400px;overflow-y:auto;white-space:pre-wrap;word-break:break-all;border:1px solid #2d333b;margin:0;"></pre>'
	html[#html+1] = '<div id="setup-log-result" style="margin-top:10px;display:none;"></div>'
	html[#html+1] = '</div>'

	-- JavaScript
	html[#html+1] = '<script type="text/javascript">'

	-- 版本选择对话框逻辑
	html[#html+1] = 'var _setupTimer=null;'
	html[#html+1] = 'var _storageLoaded=false;'
	html[#html+1] = 'var _storageCurrent="/opt/openclaw";'
	html[#html+1] = 'var _storageOptions=[];'
	html[#html+1] = 'function ocPopulateStorageSelect(sel, current){'
	html[#html+1] = 'if(!sel)return;sel.innerHTML="";'
	html[#html+1] = 'for(var i=0;i<_storageOptions.length;i++){var o=_storageOptions[i];var op=document.createElement("option");op.value=o.path;op.textContent=o.label+" (可用 "+(o.available_mb||0)+"MB"+(o.recommended?"，推荐":"")+")";op.setAttribute("data-external",o.external?"1":"0");op.setAttribute("data-writable",o.writable?"1":"0");op.setAttribute("data-mb",String(o.available_mb||0));op.setAttribute("data-fs",o.fs||"-");sel.appendChild(op);}';
	html[#html+1] = 'if(current)sel.value=current;'
	html[#html+1] = 'if(!sel.value&&sel.options.length>0)sel.selectedIndex=0;'
	html[#html+1] = '}'
	html[#html+1] = 'function ocUpdateStorageHint(){'
	html[#html+1] = 'var sel=document.getElementById("oc-storage-select-main")||document.getElementById("oc-storage-select");'
	html[#html+1] = 'var hint=document.getElementById("oc-storage-main-tip")||document.getElementById("oc-storage-hint");'
	html[#html+1] = 'if(!sel||!hint)return;'
	html[#html+1] = 'var opt=sel.options[sel.selectedIndex];'
	html[#html+1] = 'if(!opt){hint.textContent="";return;}'
	html[#html+1] = 'var ext=opt.getAttribute("data-external")==="1";'
	html[#html+1] = 'var writable=opt.getAttribute("data-writable")==="1";'
	html[#html+1] = 'var mb=parseInt(opt.getAttribute("data-mb")||"0",10);'
	html[#html+1] = 'var fs=opt.getAttribute("data-fs")||"-";'
	html[#html+1] = 'var tip=(ext?"外置存储":"系统分区")+" · 文件系统: "+fs+" · 可用空间: "+mb+" MB";'
	html[#html+1] = 'if(!writable)tip=tip+" · ⚠️ 不可写";'
	html[#html+1] = 'if(ext)tip=tip+" · 安装时会自动创建 /opt/openclaw → 外置存储 的软链接。";'
	html[#html+1] = 'hint.textContent=tip;'
	html[#html+1] = '}'
	html[#html+1] = 'function ocLoadStorageTargets(cb){'
	html[#html+1] = 'var sel=document.getElementById("oc-storage-select");'
	html[#html+1] = 'var mainSel=document.getElementById("oc-storage-select-main");'
	html[#html+1] = 'if(!sel&&!mainSel){if(cb)cb();return;}'
	html[#html+1] = '(new XHR()).get("' .. storage_url .. '",null,function(x){'
	html[#html+1] = 'try{'
	html[#html+1] = 'var r=JSON.parse(x.responseText);'
	html[#html+1] = 'if(r&&r.status==="ok"&&r.options&&r.options.length){'
	html[#html+1] = 'var keep=_storageCurrent;'
	html[#html+1] = 'if(!keep&&mainSel&&mainSel.value)keep=mainSel.value;'
	html[#html+1] = 'if(!keep&&sel&&sel.value)keep=sel.value;'
	html[#html+1] = 'if(!keep)keep="/opt/openclaw";'
	html[#html+1] = '_storageOptions=r.options;'
	html[#html+1] = '_storageCurrent=r.current||keep;'
	html[#html+1] = 'ocPopulateStorageSelect(sel,_storageCurrent);'
	html[#html+1] = 'ocPopulateStorageSelect(mainSel,_storageCurrent);'
	html[#html+1] = '_storageLoaded=true;'
	html[#html+1] = 'ocUpdateStorageHint();'
	html[#html+1] = '}'
	html[#html+1] = '}catch(e){}'
	html[#html+1] = 'if(cb)cb();'
	html[#html+1] = '});'
	html[#html+1] = '}'
	html[#html+1] = 'function ocSaveStoragePath(){'
	html[#html+1] = 'var btn=document.getElementById("btn-save-storage");'
	html[#html+1] = 'var sel=document.getElementById("oc-storage-select-main");'
	html[#html+1] = 'var el=document.getElementById("action-result");'
	html[#html+1] = 'if(!sel){return;}'
	html[#html+1] = 'var p=sel.value||"/opt/openclaw";'
	html[#html+1] = 'btn.disabled=true;btn.textContent="⏳ 保存中...";'
	html[#html+1] = '(new XHR()).get("' .. set_storage_url .. '?path="+encodeURIComponent(p),null,function(x){'
	html[#html+1] = 'btn.disabled=false;btn.textContent="💾 保存路径";'
	html[#html+1] = 'try{var r=JSON.parse(x.responseText);if(r.status==="ok"){_storageCurrent=r.path||p;el.innerHTML="<span style=\\"color:green\\">✅ 安装路径已保存: "+_storageCurrent+"</span>";var dlgSel=document.getElementById("oc-storage-select");if(dlgSel){dlgSel.value=_storageCurrent;}ocUpdateStorageHint();}else{el.innerHTML="<span style=\\"color:red\\">❌ "+(r.message||"保存失败")+"</span>";}}catch(e){el.innerHTML="<span style=\\"color:red\\">❌ 保存失败</span>";}'
	html[#html+1] = '});'
	html[#html+1] = '}'
	html[#html+1] = 'function ocShowSetupDialog(){'
	html[#html+1] = 'var dlg=document.getElementById("oc-setup-dialog");'
	html[#html+1] = 'dlg.style.display="flex";'
	html[#html+1] = 'var radios=document.getElementsByName("oc-ver-choice");'
	html[#html+1] = 'for(var i=0;i<radios.length;i++){if(radios[i].value==="stable")radios[i].checked=true;}'
	html[#html+1] = 'var mainSel=document.getElementById("oc-storage-select-main");if(mainSel&&mainSel.value){_storageCurrent=mainSel.value;}'
	html[#html+1] = '}'
	html[#html+1] = 'function ocCloseSetupDialog(){'
	html[#html+1] = 'document.getElementById("oc-setup-dialog").style.display="none";'
	html[#html+1] = '}'
	html[#html+1] = 'function ocConfirmSetup(){'
	html[#html+1] = 'ocCloseSetupDialog();'
	html[#html+1] = 'var radios=document.getElementsByName("oc-ver-choice");'
	html[#html+1] = 'var choice="stable";'
	html[#html+1] = 'for(var i=0;i<radios.length;i++){if(radios[i].checked){choice=radios[i].value;break;}}'
	html[#html+1] = 'var verParam=(choice==="stable")?"stable":"latest";'
	html[#html+1] = 'var mainSel=document.getElementById("oc-storage-select-main");'
	html[#html+1] = 'var storage=(mainSel&&mainSel.value)?mainSel.value:(_storageCurrent||"/opt/openclaw");'
	html[#html+1] = 'ocSetup(verParam,storage);'
	html[#html+1] = '}'

	-- 安装运行环境 (带实时日志)
	html[#html+1] = 'function ocSetup(version,storagePath){'
	html[#html+1] = 'var btn=document.getElementById("btn-setup");'
	html[#html+1] = 'var panel=document.getElementById("setup-log-panel");'
	html[#html+1] = 'var logEl=document.getElementById("setup-log-content");'
	html[#html+1] = 'var titleEl=document.getElementById("setup-log-title");'
	html[#html+1] = 'var statusEl=document.getElementById("setup-log-status");'
	html[#html+1] = 'var resultEl=document.getElementById("setup-log-result");'
	html[#html+1] = 'var actionEl=document.getElementById("action-result");'
	html[#html+1] = 'btn.disabled=true;btn.textContent="⏳ 安装中...";'
	html[#html+1] = 'actionEl.textContent="";'
	html[#html+1] = 'panel.style.display="block";'
	html[#html+1] = 'logEl.textContent="正在启动安装 ("+((version==="stable")?"稳定版":"最新版")+")...\\n";'
	html[#html+1] = 'if(storagePath&&storagePath!=="/opt/openclaw"){logEl.textContent=logEl.textContent+"安装存储: "+storagePath+"\\n";}'
	html[#html+1] = 'titleEl.textContent="📋 安装日志";'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#7aa2f7;\\">⏳ 安装进行中...</span>";'
	html[#html+1] = 'resultEl.style.display="none";'
	html[#html+1] = '(new XHR()).get("' .. ctl_url .. '?action=setup&version="+encodeURIComponent(version)+"&storage_path="+encodeURIComponent(storagePath||"/opt/openclaw"),null,function(x){'
	html[#html+1] = 'try{var r=JSON.parse(x.responseText);if(r.status&&r.status!=="ok"){btn.disabled=false;btn.textContent="📦 安装运行环境";statusEl.innerHTML="<span style=\\"color:#cf222e;\\">❌ 启动失败</span>";resultEl.style.display="block";resultEl.innerHTML="<div style=\\"border:1px solid #f5c6cb;background:#ffeef0;padding:12px 16px;border-radius:6px;\\"><strong style=\\"color:#cf222e;font-size:14px;\\">❌ 无法启动安装</strong><br/><span style=\\"color:#555;font-size:13px;\\">"+(r.message||"未知错误")+"</span></div>";return;}}catch(e){}'
	html[#html+1] = 'ocPollSetupLog();'
	html[#html+1] = '});'
	html[#html+1] = '}'

	-- 轮询安装日志
	html[#html+1] = 'function ocPollSetupLog(){'
	html[#html+1] = 'if(_setupTimer)clearInterval(_setupTimer);'
	html[#html+1] = '_setupTimer=setInterval(function(){'
	html[#html+1] = '(new XHR()).get("' .. log_url .. '",null,function(x){'
	html[#html+1] = 'try{'
	html[#html+1] = 'var r=JSON.parse(x.responseText);'
	html[#html+1] = 'var logEl=document.getElementById("setup-log-content");'
	html[#html+1] = 'var statusEl=document.getElementById("setup-log-status");'
	html[#html+1] = 'if(r.log)logEl.textContent=r.log;'
	html[#html+1] = 'logEl.scrollTop=logEl.scrollHeight;'
	html[#html+1] = 'if(r.state==="running"){'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#7aa2f7;\\">⏳ 安装进行中...</span>";'
	html[#html+1] = '}else if(r.state==="success"){'
	html[#html+1] = 'clearInterval(_setupTimer);_setupTimer=null;'
	html[#html+1] = 'ocSetupDone(true,r.log);'
	html[#html+1] = '}else if(r.state==="failed"){'
	html[#html+1] = 'clearInterval(_setupTimer);_setupTimer=null;'
	html[#html+1] = 'ocSetupDone(false,r.log);'
	html[#html+1] = '}'
	html[#html+1] = '}catch(e){}'
	html[#html+1] = '});'
	html[#html+1] = '},1500);'
	html[#html+1] = '}'

	-- 安装完成处理
	html[#html+1] = 'function ocSetupDone(ok,log){'
	html[#html+1] = 'var btn=document.getElementById("btn-setup");'
	html[#html+1] = 'var statusEl=document.getElementById("setup-log-status");'
	html[#html+1] = 'var resultEl=document.getElementById("setup-log-result");'
	html[#html+1] = 'btn.disabled=false;btn.textContent="📦 安装运行环境";'
	html[#html+1] = 'resultEl.style.display="block";'
	html[#html+1] = 'if(ok){'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#1a7f37;\\">✅ 安装完成</span>";'
	html[#html+1] = 'resultEl.innerHTML="<div style=\\"border:1px solid #c6e9c9;background:#e6f7e9;padding:12px 16px;border-radius:6px;\\">"+'
	html[#html+1] = '"<strong style=\\"color:#1a7f37;font-size:14px;\\">🎉 恭喜！OpenClaw 运行环境安装成功！</strong><br/>"+'
	html[#html+1] = '"<span style=\\"color:#555;font-size:13px;line-height:1.8;\\">服务已自动启用并启动，点击下方按钮刷新页面查看运行状态。</span><br/>"+'
	html[#html+1] = '"<button class=\\"btn cbi-button cbi-button-apply\\" type=\\"button\\" onclick=\\"location.reload()\\" style=\\"margin-top:10px;\\">🔄 刷新页面</button></div>";'
	html[#html+1] = '}else{'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#cf222e;\\">❌ 安装失败</span>";'
	-- 分析失败原因
	html[#html+1] = 'var reasons=ocAnalyzeFailure(log);'
	html[#html+1] = 'resultEl.innerHTML="<div style=\\"border:1px solid #f5c6cb;background:#ffeef0;padding:12px 16px;border-radius:6px;\\">"+'
	html[#html+1] = '"<strong style=\\"color:#cf222e;font-size:14px;\\">❌ 安装失败</strong><br/>"+'
	html[#html+1] = '"<div style=\\"margin:8px 0;padding:10px 14px;background:#fff5f5;border-radius:4px;font-size:13px;line-height:1.8;\\">"+'
	html[#html+1] = '"<strong>🔍 可能的失败原因：</strong><br/>"+reasons+"</div>"+'
	html[#html+1] = '"<div style=\\"margin-top:8px;font-size:12px;color:#666;\\">💡 完整日志见上方终端输出，也可在终端查看：<code>cat /tmp/openclaw-setup.log</code></div></div>";'
	html[#html+1] = '}'
	html[#html+1] = '}'

	-- 分析失败原因
	html[#html+1] = 'function ocAnalyzeFailure(log){'
	html[#html+1] = 'var reasons=[];'
	html[#html+1] = 'if(!log)return"未知错误，请检查日志。";'
	html[#html+1] = 'var ll=log.toLowerCase();'
	-- 网络问题
	html[#html+1] = 'if(ll.indexOf("could not resolve")>=0||ll.indexOf("connection timed out")>=0||ll.indexOf("curl")>=0&&ll.indexOf("fail")>=0||ll.indexOf("wget")>=0&&ll.indexOf("fail")>=0||ll.indexOf("所有镜像均下载失败")>=0){'
	html[#html+1] = 'reasons.push("🌐 <b>网络连接失败</b> — 无法下载 Node.js。请检查路由器是否能访问外网。<br/>&nbsp;&nbsp;💡 解决: 检查 DNS 设置和网络连接，或手动指定镜像: <code>NODE_MIRROR=https://npmmirror.com/mirrors/node sh /usr/bin/openclaw-env setup</code>");'
	html[#html+1] = '}'
	-- 磁盘空间
	html[#html+1] = 'if(ll.indexOf("no space")>=0||ll.indexOf("disk full")>=0||ll.indexOf("enospc")>=0){'
	html[#html+1] = 'reasons.push("💾 <b>磁盘空间不足</b> — Node.js + OpenClaw 需要约 200MB 空间。<br/>&nbsp;&nbsp;💡 解决: 运行 <code>df -h</code> 检查可用空间，清理不需要的文件或使用外部存储。");'
	html[#html+1] = '}'
	-- 架构不支持
	html[#html+1] = 'if(ll.indexOf("不支持的 cpu 架构")>=0||ll.indexOf("不支持的架构")>=0){'
	html[#html+1] = 'reasons.push("🔧 <b>CPU 架构不支持</b> — 仅支持 x86_64 和 aarch64 (ARM64)。<br/>&nbsp;&nbsp;💡 当前设备架构可能是 32 位 ARM 或 MIPS，无法运行 Node.js 22。");'
	html[#html+1] = '}'
	-- npm 安装失败
	html[#html+1] = 'if(ll.indexOf("npm err")>=0||ll.indexOf("npm warn")>=0&&ll.indexOf("openclaw 安装验证失败")>=0){'
	html[#html+1] = 'reasons.push("📦 <b>npm 安装 OpenClaw 失败</b> — npm 包下载或安装出错。<br/>&nbsp;&nbsp;💡 解决: 尝试手动安装 <code>PATH=/opt/openclaw/node/bin:$PATH npm install -g openclaw@latest --prefix=/opt/openclaw/global</code>");'
	html[#html+1] = '}'
	-- 权限问题
	html[#html+1] = 'if(ll.indexOf("permission denied")>=0||ll.indexOf("eacces")>=0){'
	html[#html+1] = 'reasons.push("🔒 <b>权限不足</b> — 文件或目录权限问题。<br/>&nbsp;&nbsp;💡 解决: 运行 <code>chown -R openclaw:openclaw /opt/openclaw</code> 或以 root 用户重试。");'
	html[#html+1] = '}'
	-- tar 解压失败
	html[#html+1] = 'if(ll.indexOf("tar")>=0&&(ll.indexOf("error")>=0||ll.indexOf("fail")>=0)){'
	html[#html+1] = 'reasons.push("📂 <b>解压失败</b> — Node.js 安装包可能下载不完整。<br/>&nbsp;&nbsp;💡 解决: 删除缓存重试 <code>rm -rf /opt/openclaw/node && sh /usr/bin/openclaw-env setup</code>");'
	html[#html+1] = '}'
	-- 验证失败
	html[#html+1] = 'if(ll.indexOf("安装验证失败")>=0){'
	html[#html+1] = 'reasons.push("⚠️ <b>安装验证失败</b> — 程序已下载但无法正常运行。<br/>&nbsp;&nbsp;💡 可能是 glibc/musl 不兼容，请确认系统 C 库类型: <code>ldd --version 2>&1 | head -1</code>");'
	html[#html+1] = '}'
	html[#html+1] = 'if(ll.indexOf("openclaw-env")>=0&&ll.indexOf("not found")>=0){'
	html[#html+1] = 'reasons.push("📦 <b>插件安装不完整</b> — 系统缺少 <code>openclaw-env</code>。<br/>&nbsp;&nbsp;💡 解决: 重新安装插件包，然后刷新 LuCI 缓存后重试。");'
	html[#html+1] = '}'
	-- 兜底
	html[#html+1] = 'if(reasons.length===0){'
	html[#html+1] = 'reasons.push("⚠️ <b>未识别的错误</b> — 请查看上方完整日志分析具体原因。<br/>&nbsp;&nbsp;💡 您也可以尝试手动执行: <code>sh /usr/bin/openclaw-env setup</code> 查看详细输出。");'
	html[#html+1] = '}'
	html[#html+1] = 'return reasons.join("<br/><br/>");'
	html[#html+1] = '}'

	-- 普通服务操作 (restart/stop)
	html[#html+1] = 'function ocServiceCtl(action){'
	html[#html+1] = 'var el=document.getElementById("action-result");'
	html[#html+1] = 'el.innerHTML="<span style=\\"color:#999\\">⏳ 正在执行...</span>";'
	html[#html+1] = '(new XHR()).get("' .. ctl_url .. '?action="+action,null,function(x){'
	html[#html+1] = 'try{var r=JSON.parse(x.responseText);'
	html[#html+1] = 'if(r.status==="ok"){el.innerHTML="<span style=\\"color:green\\">✅ "+action+" 已完成</span>";}'
	html[#html+1] = 'else{el.innerHTML="<span style=\\"color:red\\">❌ "+(r.message||"失败")+"</span>";}'
	html[#html+1] = '}catch(e){el.innerHTML="<span style=\\"color:red\\">❌ 错误</span>";}'
	html[#html+1] = '});}'

	-- 检测升级 (同时检查 OpenClaw + 插件版本)
	html[#html+1] = 'function ocCheckUpdate(){'
	html[#html+1] = 'var btn=document.getElementById("btn-check-update");'
	html[#html+1] = 'var el=document.getElementById("action-result");'
	html[#html+1] = 'var act=document.getElementById("oc-update-action");'
	html[#html+1] = 'btn.disabled=true;btn.textContent="⏳ 正在检测...";el.textContent="";act.style.display="none";'
	html[#html+1] = '(new XHR()).get("' .. check_url .. '?check_plugin=1",null,function(x){'
	html[#html+1] = 'btn.disabled=false;btn.textContent="🔍 检测升级";'
	html[#html+1] = 'var dot=document.getElementById("update-dot");if(dot)dot.style.display="none";'
	html[#html+1] = 'try{var r=JSON.parse(x.responseText);'
	html[#html+1] = 'var msgs=[];'
	-- OpenClaw 版本检查
	html[#html+1] = 'if(!r.current){msgs.push("<span style=\\"color:#999\\">⚠️ OpenClaw 运行环境未安装</span>");}'
	html[#html+1] = 'else if(r.has_update){msgs.push("<span style=\\"color:#e36209\\">📦 OpenClaw: v"+r.current+" → v"+r.latest+" (有新版本)</span>");}'
	html[#html+1] = 'else{msgs.push("<span style=\\"color:green\\">✅ OpenClaw: v"+r.current+" (已是最新)</span>");}'
	-- 插件版本检查
	html[#html+1] = 'if(r.plugin_current){'
	html[#html+1] = 'if(r.plugin_has_update){msgs.push("<span style=\\"color:#e36209\\">🔌 插件: v"+r.plugin_current+" → v"+r.plugin_latest+" (有新版本)</span>");}'
	html[#html+1] = 'else if(r.plugin_latest){msgs.push("<span style=\\"color:green\\">✅ 插件: v"+r.plugin_current+" (已是最新)</span>");}'
	html[#html+1] = 'else{msgs.push("<span style=\\"color:#999\\">🔌 插件: v"+r.plugin_current+" (无法检查最新版本)</span>");}'
	html[#html+1] = '}'
	html[#html+1] = 'el.innerHTML=msgs.join("<br/>");'
	-- 显示 OpenClaw 升级按钮
	html[#html+1] = 'if(r.has_update){'
	html[#html+1] = 'act.style.display="block";'
	html[#html+1] = 'act.innerHTML=\'<button class="btn cbi-button cbi-button-apply" type="button" onclick="ocDoUpdate()" id="btn-do-update">⬆️ 立即升级 OpenClaw</button>\';'
	html[#html+1] = '}'
	-- 插件有更新时: 一键升级按钮 + GitHub 下载链接
	html[#html+1] = 'if(r.plugin_has_update){'
	html[#html+1] = 'act.style.display="block";'
	html[#html+1] = 'window._pluginLatestVer=r.plugin_latest;'
	html[#html+1] = 'act.innerHTML=(act.innerHTML||"")+\' <button class="btn cbi-button cbi-button-apply" type="button" onclick="ocPluginUpgrade()" id="btn-plugin-upgrade">⬆️ 升级插件 v\'+r.plugin_latest+\'</button>\';'
	html[#html+1] = 'act.innerHTML=act.innerHTML+\' <a href="https://github.com/10000ge10000/luci-app-openclaw/releases/latest" target="_blank" rel="noopener" class="btn cbi-button cbi-button-action" style="text-decoration:none;">📥 手动下载</a>\';'
	html[#html+1] = '}'
	html[#html+1] = '}catch(e){el.innerHTML="<span style=\\"color:red\\">❌ 检测失败</span>";}'
	html[#html+1] = '});}'

	-- 执行升级 (带实时日志, 和安装一样的体验)
	html[#html+1] = 'var _upgradeTimer=null;'
	html[#html+1] = 'function ocDoUpdate(){'
	html[#html+1] = 'var btn=document.getElementById("btn-do-update");'
	html[#html+1] = 'var panel=document.getElementById("setup-log-panel");'
	html[#html+1] = 'var logEl=document.getElementById("setup-log-content");'
	html[#html+1] = 'var titleEl=document.getElementById("setup-log-title");'
	html[#html+1] = 'var statusEl=document.getElementById("setup-log-status");'
	html[#html+1] = 'var resultEl=document.getElementById("setup-log-result");'
	html[#html+1] = 'var actionEl=document.getElementById("action-result");'
	html[#html+1] = 'if(!confirm("确定要升级 OpenClaw？升级期间服务将短暂中断。"))return;'
	html[#html+1] = 'btn.disabled=true;btn.textContent="⏳ 正在升级...";'
	html[#html+1] = 'actionEl.textContent="";'
	html[#html+1] = 'panel.style.display="block";'
	html[#html+1] = 'logEl.textContent="正在启动升级...\\n";'
	html[#html+1] = 'titleEl.textContent="📋 升级日志";'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#7aa2f7;\\">⏳ 升级进行中...</span>";'
	html[#html+1] = 'resultEl.style.display="none";'
	html[#html+1] = '(new XHR()).get("' .. update_url .. '",null,function(x){'
	html[#html+1] = 'try{JSON.parse(x.responseText);}catch(e){}'
	html[#html+1] = 'ocPollUpgradeLog();'
	html[#html+1] = '});'
	html[#html+1] = '}'

	-- 轮询升级日志
	html[#html+1] = 'function ocPollUpgradeLog(){'
	html[#html+1] = 'if(_upgradeTimer)clearInterval(_upgradeTimer);'
	html[#html+1] = '_upgradeTimer=setInterval(function(){'
	html[#html+1] = '(new XHR()).get("' .. upgrade_log_url .. '",null,function(x){'
	html[#html+1] = 'try{'
	html[#html+1] = 'var r=JSON.parse(x.responseText);'
	html[#html+1] = 'var logEl=document.getElementById("setup-log-content");'
	html[#html+1] = 'var statusEl=document.getElementById("setup-log-status");'
	html[#html+1] = 'if(r.log)logEl.textContent=r.log;'
	html[#html+1] = 'logEl.scrollTop=logEl.scrollHeight;'
	html[#html+1] = 'if(r.state==="running"){'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#7aa2f7;\\">⏳ 升级进行中...</span>";'
	html[#html+1] = '}else if(r.state==="success"){'
	html[#html+1] = 'clearInterval(_upgradeTimer);_upgradeTimer=null;'
	html[#html+1] = 'ocUpgradeDone(true);'
	html[#html+1] = '}else if(r.state==="failed"){'
	html[#html+1] = 'clearInterval(_upgradeTimer);_upgradeTimer=null;'
	html[#html+1] = 'ocUpgradeDone(false);'
	html[#html+1] = '}'
	html[#html+1] = '}catch(e){}'
	html[#html+1] = '});'
	html[#html+1] = '},1500);'
	html[#html+1] = '}'

	-- 升级完成处理
	html[#html+1] = 'function ocUpgradeDone(ok){'
	html[#html+1] = 'var btn=document.getElementById("btn-do-update");'
	html[#html+1] = 'var statusEl=document.getElementById("setup-log-status");'
	html[#html+1] = 'var resultEl=document.getElementById("setup-log-result");'
	html[#html+1] = 'var actEl=document.getElementById("oc-update-action");'
	html[#html+1] = 'if(btn){btn.disabled=false;btn.textContent="⬆️ 立即升级";}'
	html[#html+1] = 'resultEl.style.display="block";'
	html[#html+1] = 'if(ok){'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#1a7f37;\\">✅ 升级完成</span>";'
	html[#html+1] = 'resultEl.innerHTML="<div style=\\"border:1px solid #c6e9c9;background:#e6f7e9;padding:12px 16px;border-radius:6px;\\">"+'
	html[#html+1] = '"<strong style=\\"color:#1a7f37;font-size:14px;\\">🎉 升级成功！服务已自动重启。</strong><br/>"+'
	html[#html+1] = '"<span style=\\"color:#555;font-size:13px;line-height:1.8;\\">点击下方按钮刷新页面查看最新状态。</span><br/>"+'
	html[#html+1] = '"<button class=\\"btn cbi-button cbi-button-apply\\" type=\\"button\\" onclick=\\"location.reload()\\" style=\\"margin-top:10px;\\">🔄 刷新页面</button></div>";'
	html[#html+1] = 'actEl.style.display="none";'
	html[#html+1] = '}else{'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#cf222e;\\">❌ 升级失败</span>";'
	html[#html+1] = 'resultEl.innerHTML="<div style=\\"border:1px solid #f5c6cb;background:#ffeef0;padding:12px 16px;border-radius:6px;\\">"+'
	html[#html+1] = '"<strong style=\\"color:#cf222e;font-size:14px;\\">❌ 升级失败</strong><br/>"+'
	html[#html+1] = '"<span style=\\"color:#555;font-size:13px;\\">请查看上方日志了解详情。也可在终端查看：<code>cat /tmp/openclaw-upgrade.log</code></span><br/>"+'
	html[#html+1] = '"<button class=\\"btn cbi-button cbi-button-apply\\" type=\\"button\\" onclick=\\"location.reload()\\" style=\\"margin-top:10px;\\">🔄 刷新页面</button></div>";'
	html[#html+1] = '}'
	html[#html+1] = '}'

	-- ═══ 插件一键升级 ═══
	html[#html+1] = 'var _pluginUpgradeTimer=null;'

	html[#html+1] = 'function ocPluginUpgrade(){'
	html[#html+1] = 'var ver=window._pluginLatestVer;'
	html[#html+1] = 'if(!ver){alert("无法获取最新版本号");return;}'
	html[#html+1] = 'if(!confirm("确定要升级插件到 v"+ver+"？\\n\\n升级会替换插件文件并清除 LuCI 缓存，不会影响正在运行的 OpenClaw 服务。"))return;'
	html[#html+1] = 'var btn=document.getElementById("btn-plugin-upgrade");'
	html[#html+1] = 'var panel=document.getElementById("setup-log-panel");'
	html[#html+1] = 'var logEl=document.getElementById("setup-log-content");'
	html[#html+1] = 'var titleEl=document.getElementById("setup-log-title");'
	html[#html+1] = 'var statusEl=document.getElementById("setup-log-status");'
	html[#html+1] = 'var resultEl=document.getElementById("setup-log-result");'
	html[#html+1] = 'btn.disabled=true;btn.textContent="⏳ 正在升级插件...";'
	html[#html+1] = 'panel.style.display="block";'
	html[#html+1] = 'logEl.textContent="正在启动插件升级...\\n";'
	html[#html+1] = 'titleEl.textContent="📋 插件升级日志";'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#7aa2f7;\\">⏳ 插件升级中...</span>";'
	html[#html+1] = 'resultEl.style.display="none";'
	html[#html+1] = '(new XHR()).get("' .. plugin_upgrade_url .. '?version="+encodeURIComponent(ver),null,function(x){'
	html[#html+1] = 'try{JSON.parse(x.responseText);}catch(e){}'
	html[#html+1] = 'ocPollPluginUpgradeLog();'
	html[#html+1] = '});'
	html[#html+1] = '}'

	-- 轮询插件升级日志 (带容错: 安装时文件被替换可能导致API暂时不可用)
	html[#html+1] = 'var _pluginPollErrors=0;'
	html[#html+1] = 'function ocPollPluginUpgradeLog(){'
	html[#html+1] = 'if(_pluginUpgradeTimer)clearInterval(_pluginUpgradeTimer);'
	html[#html+1] = '_pluginPollErrors=0;'
	html[#html+1] = '_pluginUpgradeTimer=setInterval(function(){'
	html[#html+1] = '(new XHR()).get("' .. plugin_upgrade_log_url .. '",null,function(x){'
	html[#html+1] = 'try{'
	html[#html+1] = 'var r=JSON.parse(x.responseText);'
	html[#html+1] = '_pluginPollErrors=0;'
	html[#html+1] = 'var logEl=document.getElementById("setup-log-content");'
	html[#html+1] = 'var statusEl=document.getElementById("setup-log-status");'
	html[#html+1] = 'if(r.log)logEl.textContent=r.log;'
	html[#html+1] = 'logEl.scrollTop=logEl.scrollHeight;'
	html[#html+1] = 'if(r.state==="running"){'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#7aa2f7;\\">⏳ 插件升级中...</span>";'
	html[#html+1] = '}else if(r.state==="success"){'
	html[#html+1] = 'clearInterval(_pluginUpgradeTimer);_pluginUpgradeTimer=null;'
	html[#html+1] = 'ocPluginUpgradeDone(true);'
	html[#html+1] = '}else if(r.state==="failed"){'
	html[#html+1] = 'clearInterval(_pluginUpgradeTimer);_pluginUpgradeTimer=null;'
	html[#html+1] = 'ocPluginUpgradeDone(false);'
	html[#html+1] = '}'
	html[#html+1] = '}catch(e){'
	html[#html+1] = '_pluginPollErrors++;'
	html[#html+1] = 'if(_pluginPollErrors>=8){'
	html[#html+1] = 'clearInterval(_pluginUpgradeTimer);_pluginUpgradeTimer=null;'
	html[#html+1] = 'ocPluginUpgradeDone(true);'
	html[#html+1] = '}'
	html[#html+1] = '}'
	html[#html+1] = '});'
	html[#html+1] = '},2000);'
	html[#html+1] = '}'

	-- 插件升级完成处理
	html[#html+1] = 'function ocPluginUpgradeDone(ok){'
	html[#html+1] = 'var btn=document.getElementById("btn-plugin-upgrade");'
	html[#html+1] = 'var statusEl=document.getElementById("setup-log-status");'
	html[#html+1] = 'var resultEl=document.getElementById("setup-log-result");'
	html[#html+1] = 'if(btn){btn.disabled=false;btn.textContent="⬆️ 升级插件";}'
	html[#html+1] = 'resultEl.style.display="block";'
	html[#html+1] = 'if(ok){'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#1a7f37;\\">✅ 插件升级完成</span>";'
	html[#html+1] = 'resultEl.innerHTML="<div style=\\"border:1px solid #c6e9c9;background:#e6f7e9;padding:12px 16px;border-radius:6px;\\">"+'
	html[#html+1] = '"<strong style=\\"color:#1a7f37;font-size:14px;\\">🎉 插件升级成功！</strong><br/>"+'
	html[#html+1] = '"<span style=\\"color:#555;font-size:13px;line-height:1.8;\\">插件文件已更新，OpenClaw 服务不受影响。请刷新页面加载新版界面。</span><br/>"+'
	html[#html+1] = '"<button class=\\"btn cbi-button cbi-button-apply\\" type=\\"button\\" onclick=\\"location.reload()\\" style=\\"margin-top:10px;\\">🔄 刷新页面</button></div>";'
	html[#html+1] = '}else{'
	html[#html+1] = 'statusEl.innerHTML="<span style=\\"color:#cf222e;\\">❌ 插件升级失败</span>";'
	html[#html+1] = 'resultEl.innerHTML="<div style=\\"border:1px solid #f5c6cb;background:#ffeef0;padding:12px 16px;border-radius:6px;\\">"+'
	html[#html+1] = '"<strong style=\\"color:#cf222e;font-size:14px;\\">❌ 插件升级失败</strong><br/>"+'
	html[#html+1] = '"<span style=\\"color:#555;font-size:13px;\\">请查看上方日志了解详情。也可手动执行：<code>cat /tmp/openclaw-plugin-upgrade.log</code></span><br/>"+'
	html[#html+1] = '"<button class=\\"btn cbi-button cbi-button-apply\\" type=\\"button\\" onclick=\\"location.reload()\\" style=\\"margin-top:10px;\\">🔄 刷新页面</button></div>";'
	html[#html+1] = '}'
	html[#html+1] = '}'

	-- 卸载运行环境
	html[#html+1] = 'function ocUninstall(){'
	html[#html+1] = 'if(!confirm("确定要卸载 OpenClaw 运行环境？\\n\\n将删除 Node.js、OpenClaw 程序及配置数据（/opt/openclaw 目录），服务将停止运行。\\n\\n插件本身不会被删除，之后可重新安装运行环境。"))return;'
	html[#html+1] = 'var btn=document.getElementById("btn-uninstall");'
	html[#html+1] = 'var el=document.getElementById("action-result");'
	html[#html+1] = 'btn.disabled=true;btn.textContent="⏳ 正在卸载...";'
	html[#html+1] = 'el.innerHTML="<span style=\\"color:#999\\">正在停止服务并清理文件...</span>";'
	html[#html+1] = '(new XHR()).get("' .. uninstall_url .. '",null,function(x){'
	html[#html+1] = 'btn.disabled=false;btn.textContent="🗑️ 卸载环境";'
	html[#html+1] = 'try{var r=JSON.parse(x.responseText);'
	html[#html+1] = 'if(r.status==="ok"){'
	html[#html+1] = 'el.innerHTML="<div style=\\"border:1px solid #d0d7de;background:#f6f8fa;padding:12px 16px;border-radius:6px;\\">"+'
	html[#html+1] = '"<strong style=\\"color:#1a7f37;\\">✅ 卸载完成</strong><br/>"+'
	html[#html+1] = '"<span style=\\"color:#555;font-size:13px;\\">"+r.message+"</span><br/>"+'
	html[#html+1] = '"<button class=\\"btn cbi-button cbi-button-apply\\" type=\\"button\\" onclick=\\"location.reload()\\" style=\\"margin-top:8px;\\">🔄 刷新页面</button></div>";'
	html[#html+1] = '}else{el.innerHTML="<span style=\\"color:red\\">❌ "+(r.message||"卸载失败")+"</span>";}'
	html[#html+1] = '}catch(e){el.innerHTML="<span style=\\"color:red\\">❌ 请求失败</span>";}'
	html[#html+1] = '});}'

	-- 页面加载时静默检查是否有更新 (仅显示小红点提示)
	html[#html+1] = '(function(){'
	html[#html+1] = 'var mainSel=document.getElementById("oc-storage-select-main");'
	html[#html+1] = 'if(mainSel&&!mainSel.getAttribute("data-bind")){mainSel.setAttribute("data-bind","1");mainSel.onchange=function(){_storageCurrent=this.value;ocUpdateStorageHint();};}'
	html[#html+1] = 'ocLoadStorageTargets();'
	html[#html+1] = 'setTimeout(function(){'
	html[#html+1] = '(new XHR()).get("' .. check_url .. '?quick=1",null,function(x){'
	html[#html+1] = 'try{var r=JSON.parse(x.responseText);'
	html[#html+1] = 'if(r.has_update||r.plugin_has_update){'
	html[#html+1] = 'var dot=document.getElementById("update-dot");'
	html[#html+1] = 'if(dot)dot.style.display="block";'
	html[#html+1] = '}'
	html[#html+1] = '}catch(e){}'
	html[#html+1] = '});'
	html[#html+1] = '},2000);'
	html[#html+1] = '})();'

	html[#html+1] = '</script>'
	return table.concat(html, "\n")
end

-- ═══════════════════════════════════════════
-- 使用指南
-- ═══════════════════════════════════════════
s4 = m:section(SimpleSection, nil)
s4.template = "cbi/nullsection"
guide = s4:option(DummyValue, "_guide")
guide.rawhtml = true
guide.cfgvalue = function()
	local html = {}
	html[#html+1] = '<div style="border:1px solid #d0e8ff;background:#f0f7ff;padding:14px 18px;border-radius:6px;margin-top:12px;line-height:1.8;font-size:13px;">'
	html[#html+1] = '<strong style="font-size:14px;">📖 使用指南</strong><br/>'
	html[#html+1] = '<span style="color:#555;">'
	html[#html+1] = '① 首次使用请点击 <b>「安装运行环境」</b>，安装完成后服务会自动启动<br/>'
	html[#html+1] = '② 进入 <b>「配置管理」</b> 使用交互式向导快速配置 AI 模型和 API Key<br/>'
	html[#html+1] = '③ 进入 <b>「Web 控制台」</b> 配置消息渠道，直接开始对话</span>'
	html[#html+1] = '<div style="margin-top:10px;padding-top:10px;border-top:1px solid #d0e8ff;">'
	html[#html+1] = '<span style="color:#888;">有疑问？请关注B站并留言：</span>'
	html[#html+1] = '<a href="https://space.bilibili.com/59438380" target="_blank" rel="noopener" style="color:#00a1d6;font-weight:bold;text-decoration:none;">'
	html[#html+1] = '🔗 space.bilibili.com/59438380</a>'
	html[#html+1] = '<span style="margin-left:16px;color:#888;">GitHub 项目：</span>'
	html[#html+1] = '<a href="https://github.com/10000ge10000/luci-app-openclaw" target="_blank" rel="noopener" style="color:#24292f;font-weight:bold;text-decoration:none;">'
	html[#html+1] = '🐙 10000ge10000/luci-app-openclaw</a></div></div>'
	return table.concat(html, "\n")
end

return m
