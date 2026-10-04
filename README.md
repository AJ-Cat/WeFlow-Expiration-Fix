# WeFlow-Expiration-Fix

通过临时修改系统日期时间的方式，让已过期的 WeFlow 能够启动并继续使用导出功能。

> **免责声明**  
> 本项目仅供个人备份、导出本人微信聊天记录使用。请勿用于任何商业用途或侵犯他人隐私。使用本脚本可能违反微信用户协议，并可能导致账号被风控。一切风险由使用者自行承担。

---

## 问题背景

WeFlow 依赖 `wcdb_api.dll` 读取微信本地数据库。该 DLL 内部硬编码了一个过期时间：

```
2026-09-30 23:59:59
```

一旦系统时间超过这个日期，DLL 的 `InitProtection` 接口就会返回错误码 `-101`，导致 WeFlow 核心功能无法打开。

社区补丁（WeFlow-Community-Patch）虽然绕过了 WeLive 引擎的过期检查，但最终仍然要调用 `wcdb_api.dll`，所以 **补丁也无法解决 `-101` 问题**。

目前唯一可行的临时方案是：**在启动 WeFlow 之前，把系统时间改到过期日之前；等 WeFlow 完成初始化后，再把系统时间恢复。**

---

## 工作原理

1. WeFlow 启动时，`wcdb_api.dll` 会读取当前系统时间，与内置的 `2026-09-30 23:59:59` 比较。
2. 如果当前时间早于过期时间，检查通过，DLL 标记为已授权，后续操作不再重复检查。
3. 因此，我们可以在启动前把系统时间设到 `2026-07-31`，启动 WeFlow，等待 10 秒左右让其完成初始化。
4. 初始化完成后，再把系统时间恢复为正确时间。当前 WeFlow 进程通常仍可继续使用。
5. 一旦关闭 WeFlow，下次启动必须重新执行此流程。

---

## 使用方法

本仓库已包含修复脚本 **`Start-WeFlow.ps1`**，直接下载运行即可。

### 1. 下载脚本

从本仓库下载 `Start-WeFlow.ps1`：

- 直接下载：点击仓库中的 `Start-WeFlow.ps1`，然后点击“Raw”或“Download”。
- 或使用命令行下载（将链接替换为本仓库的 raw 地址）：
  ```powershell
  iwr 'https://raw.githubusercontent.com/AJ-Cat/WeFlow-Expiration-Fix/main/Start-WeFlow.ps1' -OutFile Start-WeFlow.ps1
  ```

### 2. 本地运行

1. 右键点击 `Start-WeFlow.ps1`，选择 **“使用 PowerShell 运行”**。
2. 如果提示执行策略限制，请以管理员身份打开 PowerShell，先执行：
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   ```
   然后运行：
   ```powershell
   .\Start-WeFlow.ps1
   ```

### 3. 远程运行（从网络直接加载）

如果你不想把脚本保存到本地，可以在**管理员身份**的 PowerShell 中直接执行：

```powershell
powershell -ExecutionPolicy Bypass -Command "iex (iwr 'https://raw.githubusercontent.com/AJ-Cat/WeFlow-Expiration-Fix/main/Start-WeFlow.ps1').Content"
```

或使用 `Net.WebClient`：

```powershell
IEX(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/AJ-Cat/WeFlow-Expiration-Fix/main/Start-WeFlow.ps1')
```

> **注意**：远程加载的脚本会在内存中执行，不会留下文件。请确保链接是 raw 直链，并且你完全信任该脚本内容。

---

## 脚本配置

脚本顶部有以下可修改变量：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `$WeFlowPath` | WeFlow 可执行文件路径 | `C:\Users\你的用户名\AppData\Local\Programs\WeFlow\WeFlow.exe` |
| `$FakeDate` | 临时设置的系统时间，必须早于 `2026-09-30` | `2026-07-31 12:00:00` |
| `$WaitSeconds` | 启动 WeFlow 后等待多少秒再恢复时间 | `10` |

如果 WeFlow 安装在其他位置，请修改 `$WeFlowPath`。  
如果 10 秒不够，可以适当增大 `$WaitSeconds`（例如 15 或 20）。

---

## 注意事项

- **只对本次 WeFlow 进程有效**。关闭 WeFlow 后，下次启动必须重新运行脚本。
- 脚本需要**管理员权限**，因为要修改系统时间和停止/启动 Windows 时间服务。
- 运行期间，其他依赖系统时间的程序（浏览器、开发工具等）可能短暂异常，10 秒后恢复。
- **不保证每次都能成功**。部分用户反馈即使修改时间，仍可能遇到 `-1003 Challenge` 等错误。
- 如果 WeFlow 在启动后重新加载了 DLL 或启动了新的子进程，时间恢复后可能再次触发 `-101`。
- 建议在导出重要数据前，先备份 WeFlow 数据目录（通常在 `%APPDATA%\WeFlow` 或安装目录下）。
- 本项目不提供任何破解或修改 `wcdb_api.dll` 的方法，仅通过临时调整系统时间绕过启动检查。

---

## 替代方案

如果本方法不稳定，可以考虑以下不依赖 `wcdb_api.dll` 过期机制的工具：

- **chatlog**：支持微信 3.x/4.x，自动解密数据库，提供 HTTP API。
- **WeLive**：原 WeFlow 作者开发，功能强大。
- **Wetrace**：提供可视化 Web 界面，支持导出法律取证格式。
- **WeChatMsg**：老牌开源微信记录导出工具。

请自行评估各工具的风险与合规性。

---

## 参考

- [WeFlow 社区补丁 Issue #1](https://github.com/AnonymousUser443/WeFlow-Community-Patch/issues/1)
- [腾讯 WCDB 官方仓库](https://github.com/Tencent/wcdb)
- [WeFlow 原仓库（已下架）](https://github.com/hicccc77/WeFlow)

---

## License

MIT
