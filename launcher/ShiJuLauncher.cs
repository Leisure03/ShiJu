using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace ShiJuDesktop
{
    internal static class Program
    {
        private const int PreferredPort = 18689;
        private const string BundleVersion = "1.0.6";

        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            string appDataRoot = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ShiJuApp"
            );
            string wwwRoot = EnsureWebAssetsExtracted(appDataRoot);

            int port = PreferredPort;
            TcpListener listener = null;
            bool serverStartedByUs = false;

            try
            {
                listener = new TcpListener(IPAddress.Loopback, port);
                listener.Start();
                serverStartedByUs = true;
            }
            catch (SocketException)
            {
                if (IsPortResponding(port))
                {
                    LaunchAppWindow(port, appDataRoot, waitForExit: false);
                    return;
                }
                listener = new TcpListener(IPAddress.Loopback, 0);
                listener.Start();
                port = ((IPEndPoint)listener.LocalEndpoint).Port;
                serverStartedByUs = true;
            }

            if (serverStartedByUs && listener != null)
            {
                Thread serverThread = new Thread(() => RunHttpServer(listener, wwwRoot))
                {
                    IsBackground = true,
                    Name = "ShiJuLocalServer"
                };
                serverThread.Start();
            }

            LaunchAppWindow(port, appDataRoot, waitForExit: true);

            try
            {
                if (listener != null)
                {
                    listener.Stop();
                }
            }
            catch
            {
            }
        }

        private static string EnsureWebAssetsExtracted(string appDataRoot)
        {
            string exeDir = AppDomain.CurrentDomain.BaseDirectory;
            string localBuildWeb = Path.Combine(exeDir, "build", "web");
            if (File.Exists(Path.Combine(localBuildWeb, "index.html")) &&
                File.Exists(Path.Combine(localBuildWeb, "main.dart.js")))
            {
                return localBuildWeb;
            }

            string targetWww = Path.Combine(appDataRoot, "www_" + BundleVersion);
            string markerFile = Path.Combine(targetWww, ".extracted_ok");

            if (File.Exists(markerFile) && File.Exists(Path.Combine(targetWww, "index.html")))
            {
                return targetWww;
            }

            if (Directory.Exists(targetWww))
            {
                try { Directory.Delete(targetWww, true); } catch { }
            }
            Directory.CreateDirectory(targetWww);

            Assembly asm = Assembly.GetExecutingAssembly();
            using (Stream resourceStream = asm.GetManifestResourceStream("web_bundle.zip"))
            {
                if (resourceStream == null)
                {
                    MessageBox.Show(
                        "\u672a\u627e\u5230\u5185\u5d4c\u7684\u62fe\u53e5\uff08ShiJu\uff09\u8d44\u6e90\u5305\u3002",
                        "\u62fe\u53e5 (ShiJu)",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error
                    );
                    Environment.Exit(1);
                }

                using (ZipArchive archive = new ZipArchive(resourceStream, ZipArchiveMode.Read))
                {
                    foreach (ZipArchiveEntry entry in archive.Entries)
                    {
                        string fullPath = Path.Combine(targetWww, entry.FullName.Replace('/', Path.DirectorySeparatorChar));
                        if (string.IsNullOrEmpty(entry.Name))
                        {
                            Directory.CreateDirectory(fullPath);
                            continue;
                        }
                        string parentDir = Path.GetDirectoryName(fullPath);
                        if (!string.IsNullOrEmpty(parentDir))
                        {
                            Directory.CreateDirectory(parentDir);
                        }
                        using (Stream entryStream = entry.Open())
                        using (FileStream outStream = File.Create(fullPath))
                        {
                            entryStream.CopyTo(outStream);
                        }
                    }
                }
            }

            File.WriteAllText(markerFile, DateTime.UtcNow.ToString("O"));
            return targetWww;
        }

        private static bool IsPortResponding(int port)
        {
            try
            {
                using (TcpClient client = new TcpClient())
                {
                    IAsyncResult result = client.BeginConnect(IPAddress.Loopback, port, null, null);
                    bool success = result.AsyncWaitHandle.WaitOne(TimeSpan.FromMilliseconds(300));
                    return success && client.Connected;
                }
            }
            catch
            {
                return false;
            }
        }

        private static void RunHttpServer(TcpListener listener, string wwwRoot)
        {
            while (true)
            {
                try
                {
                    TcpClient client = listener.AcceptTcpClient();
                    ThreadPool.QueueUserWorkItem(_ => HandleClient(client, wwwRoot));
                }
                catch
                {
                    break;
                }
            }
        }

        private static string ResolveArtifactFilePath(string relativeArtifactPath, string wwwRoot)
        {
            string normalized = relativeArtifactPath.TrimStart('/').Replace('/', Path.DirectorySeparatorChar);
            string exeDir = AppDomain.CurrentDomain.BaseDirectory;
            string candidate1 = Path.GetFullPath(Path.Combine(exeDir, normalized));
            if (candidate1.StartsWith(Path.GetFullPath(exeDir), StringComparison.OrdinalIgnoreCase) &&
                File.Exists(candidate1))
            {
                return candidate1;
            }

            string candidate2 = Path.GetFullPath(Path.Combine(wwwRoot, normalized));
            if (candidate2.StartsWith(Path.GetFullPath(wwwRoot), StringComparison.OrdinalIgnoreCase) &&
                File.Exists(candidate2))
            {
                return candidate2;
            }

            return null;
        }

        private static void HandleClient(TcpClient client, string wwwRoot)
        {
            using (client)
            {
                try
                {
                    using (NetworkStream stream = client.GetStream())
                    using (StreamReader reader = new StreamReader(stream, Encoding.UTF8, false, 4096, true))
                    {
                        string requestLine = reader.ReadLine();
                        if (string.IsNullOrEmpty(requestLine)) return;

                        string headerLine;
                        while (!string.IsNullOrEmpty(headerLine = reader.ReadLine())) { }

                        string[] parts = requestLine.Split(' ');
                        if (parts.Length < 2) return;

                        string fullRawTarget = parts[1];
                        string queryString = "";
                        int queryIdx = fullRawTarget.IndexOf('?');
                        string pathPart = fullRawTarget;
                        if (queryIdx >= 0)
                        {
                            pathPart = fullRawTarget.Substring(0, queryIdx);
                            queryString = fullRawTarget.Substring(queryIdx + 1);
                        }

                        string rawUrl = Uri.UnescapeDataString(pathPart);
                        string relativePath = rawUrl.TrimStart('/');
                        if (string.IsNullOrEmpty(relativePath))
                        {
                            relativePath = "index.html";
                        }

                        // 1. Handle /api/reveal?path=dist/... to reveal file in Windows Explorer
                        if (relativePath.Equals("api/reveal", StringComparison.OrdinalIgnoreCase))
                        {
                            string targetRel = "";
                            foreach (string kv in queryString.Split('&'))
                            {
                                if (kv.StartsWith("path=", StringComparison.OrdinalIgnoreCase))
                                {
                                    targetRel = Uri.UnescapeDataString(kv.Substring(5));
                                    break;
                                }
                            }
                            string resolved = ResolveArtifactFilePath(targetRel, wwwRoot);
                            if (!string.IsNullOrEmpty(resolved) && File.Exists(resolved))
                            {
                                Process.Start(new ProcessStartInfo
                                {
                                    FileName = "explorer.exe",
                                    Arguments = "/select,\"" + resolved + "\"",
                                    UseShellExecute = true
                                });
                                WriteResponse(stream, "200 OK", "application/json; charset=utf-8", Encoding.UTF8.GetBytes("{\"ok\":true}"), null);
                            }
                            else
                            {
                                WriteResponse(stream, "404 Not Found", "application/json; charset=utf-8", Encoding.UTF8.GetBytes("{\"ok\":false}"), null);
                            }
                            return;
                        }

                        // 2. Handle /dist/... artifact downloads
                        if (relativePath.StartsWith("dist/", StringComparison.OrdinalIgnoreCase))
                        {
                            string artifactFile = ResolveArtifactFilePath(relativePath, wwwRoot);
                            if (!string.IsNullOrEmpty(artifactFile) && File.Exists(artifactFile))
                            {
                                byte[] artifactBody = File.ReadAllBytes(artifactFile);
                                string artifactMime = GetMimeType(Path.GetExtension(artifactFile));
                                WriteResponse(stream, "200 OK", artifactMime, artifactBody, Path.GetFileName(artifactFile));
                                return;
                            }
                            WriteResponse(stream, "404 Not Found", "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("Artifact Not Found"), null);
                            return;
                        }

                        string filePath = Path.GetFullPath(
                            Path.Combine(wwwRoot, relativePath.Replace('/', Path.DirectorySeparatorChar))
                        );

                        if (!filePath.StartsWith(Path.GetFullPath(wwwRoot), StringComparison.OrdinalIgnoreCase) ||
                            !File.Exists(filePath))
                        {
                            filePath = Path.Combine(wwwRoot, "index.html");
                        }

                        if (!File.Exists(filePath))
                        {
                            WriteResponse(stream, "404 Not Found", "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("Not Found"), null);
                            return;
                        }

                        byte[] body = File.ReadAllBytes(filePath);
                        string contentType = GetMimeType(Path.GetExtension(filePath));
                        WriteResponse(stream, "200 OK", contentType, body, null);
                    }
                }
                catch
                {
                }
            }
        }

        private static void WriteResponse(NetworkStream stream, string status, string contentType, byte[] body, string attachmentFileName)
        {
            StringBuilder sb = new StringBuilder();
            sb.Append("HTTP/1.1 ").Append(status).Append("\r\n");
            sb.Append("Content-Type: ").Append(contentType).Append("\r\n");
            sb.Append("Content-Length: ").Append(body.Length).Append("\r\n");
            if (!string.IsNullOrEmpty(attachmentFileName))
            {
                string encodedName = Uri.EscapeDataString(attachmentFileName);
                sb.Append("Content-Disposition: attachment; filename=\"").Append(encodedName).Append("\"; filename*=UTF-8''").Append(encodedName).Append("\r\n");
            }
            sb.Append("Cache-Control: no-cache\r\n");
            sb.Append("Access-Control-Allow-Origin: *\r\n");
            sb.Append("Connection: close\r\n\r\n");

            byte[] headerBytes = Encoding.ASCII.GetBytes(sb.ToString());
            stream.Write(headerBytes, 0, headerBytes.Length);
            stream.Write(body, 0, body.Length);
            stream.Flush();
        }

        private static string GetMimeType(string ext)
        {
            if (string.IsNullOrEmpty(ext)) return "application/octet-stream";
            switch (ext.ToLowerInvariant())
            {
                case ".html":
                case ".htm":
                    return "text/html; charset=utf-8";
                case ".js":
                case ".mjs":
                    return "application/javascript; charset=utf-8";
                case ".css":
                    return "text/css; charset=utf-8";
                case ".json":
                    return "application/json; charset=utf-8";
                case ".xml":
                    return "application/xml; charset=utf-8";
                case ".apk":
                    return "application/vnd.android.package-archive";
                case ".zip":
                    return "application/zip";
                case ".wasm":
                    return "application/wasm";
                case ".png":
                    return "image/png";
                case ".jpg":
                case ".jpeg":
                    return "image/jpeg";
                case ".gif":
                    return "image/gif";
                case ".svg":
                    return "image/svg+xml";
                case ".ico":
                    return "image/x-icon";
                case ".ttf":
                    return "font/ttf";
                case ".otf":
                    return "font/otf";
                case ".woff":
                    return "font/woff";
                case ".woff2":
                    return "font/woff2";
                case ".frag":
                    return "application/octet-stream";
                default:
                    return "application/octet-stream";
            }
        }

        private static void LaunchAppWindow(int port, string appDataRoot, bool waitForExit)
        {
            string url = "http://127.0.0.1:" + port + "/";
            string browserExe = FindChromiumBrowser();

            if (!string.IsNullOrEmpty(browserExe))
            {
                string profileDir = Path.Combine(appDataRoot, "AppProfile");
                Directory.CreateDirectory(profileDir);

                string args = string.Format(
                    "--app=\"{0}\" --window-size=1180,860 --user-data-dir=\"{1}\" --no-first-run --no-default-browser-check --disable-features=Translate",
                    url,
                    profileDir
                );

                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = browserExe,
                    Arguments = args,
                    UseShellExecute = false
                };

                Process proc = Process.Start(psi);
                if (waitForExit && proc != null)
                {
                    proc.WaitForExit();
                }
                return;
            }

            Process.Start(new ProcessStartInfo
            {
                FileName = url,
                UseShellExecute = true
            });
            if (waitForExit)
            {
                Thread.Sleep(TimeSpan.FromHours(6));
            }
        }

        private static string FindChromiumBrowser()
        {
            string[] candidates = new string[]
            {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Microsoft\Edge\Application\msedge.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Google\Chrome\Application\chrome.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Google\Chrome\Application\chrome.exe")
            };

            foreach (string path in candidates)
            {
                if (File.Exists(path))
                {
                    return path;
                }
            }
            return null;
        }
    }
}
