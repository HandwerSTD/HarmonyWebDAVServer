# @handwer/webdav-server

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-2.0.2-green.svg)](oh-package.json5)
[![HarmonyOS](https://img.shields.io/badge/platform-HarmonyOS-orange.svg)](https://www.harmonyos.com/)

鸿蒙 Web 服务器框架，提供类 Express.js API，支持中间件、路由、静态文件服务、WebDAV 协议等完整功能。

## 目录

- [特性](#特性)
- [安装](#安装)
- [快速开始](#快速开始)
- [API 文档](#api-文档)
  - [核心类](#核心类)
  - [中间件](#中间件)
  - [类型定义](#类型定义)
- [示例](#示例)
- [许可证](#许可证)

---

## 特性

- **完整的 HTTP/HTTPS 服务器** - 支持 HTTP 和 HTTPS（TLS）协议
- **类 Express.js API** - 熟悉的路由和中间件模式
- **路由系统** - 支持参数路由、动态路由管理
- **中间件支持** - 内置多种中间件，支持自定义中间件
- **请求体解析** - 支持 JSON、URL编码、multipart、text/plain 等格式
- **静态文件服务** - 支持缓存、ETag、Range 请求（断点续传）
- **CORS 跨域** - 完整的跨域资源共享支持
- **日志记录** - 多种日志格式（dev、combined、common、short、tiny）
- **文件上传** - 支持 multipart/form-data 和流式上传
- **流式传输** - 支持分块传输编码（Chunked Transfer Encoding）
- **WebDAV 协议** - 完整的 WebDAV 服务器实现
- **事件系统** - 服务器生命周期和请求事件监听
- **TypeScript 支持** - 完整的类型定义

---

## 安装

在您的 HarmonyOS 项目中安装：

```typescript
// oh-package.json5
{
  "dependencies": {
    "@handwer/webdav-server": "^2.0.2"
  }
}
```

---

## 快速开始

### 基础 HTTP 服务器

```typescript
import { HttpServer, HttpRequest, HttpResponse } from '@handwer/webdav-server';

// 创建服务器
const server = new HttpServer();

// 启用日志和 CORS
server.logger();
server.cors();

// 启用请求体自动解析
server.auto();

// 定义路由
server.get('/', async (req: HttpRequest, res: HttpResponse) => {
  res.json({ message: 'Hello World' });
});

server.get('/users/:id', async (req: HttpRequest, res: HttpResponse) => {
  const userId = req.params['id'];
  res.json({ userId });
});

server.post('/api/data', async (req: HttpRequest, res: HttpResponse) => {
  // req.body 已自动解析
  res.json({ received: req.body });
});

// 启动服务器
const info = await server.startServer(8080);
console.log(`Server running at http://${info.address}:${info.port}`);
```

### HTTPS 服务器

```typescript
import { TLSServer, CertManager } from '@handwer/webdav-server';

// 加载证书
const tlsOptions = await CertManager.loadFromFiles(
  '/path/to/private.key',
  '/path/to/certificate.crt'
);

// 创建 HTTPS 服务器
const server = new TLSServer(tlsOptions);

// 配置路由...
server.get('/', async (req, res) => {
  res.json({ secure: true });
});

// 启动服务器
const info = await server.startServer(8443);
console.log(`HTTPS Server running at https://${info.address}:${info.port}`);
```

### WebDAV 服务器

```typescript
import { WebDAVServer } from '@handwer/webdav-server';

// 创建 WebDAV 服务器
const webdav = new WebDAVServer({
  port: 8080,
  enableLogging: true
});

// 挂载虚拟路径到物理路径
webdav.mount('/documents', '/data/storage/documents');
webdav.mount('/photos', '/data/storage/photos');

// 启动服务器
await webdav.start();
```

---

## API 文档

### 核心类

#### HttpServer

HTTP 服务器主类，提供完整的 HTTP 服务功能。

**构造函数**

```typescript
constructor()
```

创建一个新的 HTTP 服务器实例，自动设置默认 404 处理。

**配置方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `setConfig(key, value)` | `key: string, value: Object` | `void` | 设置配置项 |
| `getConfig(key)` | `key: string` | `Object \| undefined` | 获取配置项 |

**路由方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `use(handler)` | `RequestHandler \| ErrorHandler` | `void` | 注册中间件或错误处理中间件 |
| `get(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 GET 路由 |
| `post(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 POST 路由 |
| `put(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 PUT 路由 |
| `delete(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 DELETE 路由 |
| `patch(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 PATCH 路由 |
| `head(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 HEAD 路由 |
| `options(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 OPTIONS 路由 |
| `propfind(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 PROPFIND 路由（WebDAV） |
| `copy(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 COPY 路由（WebDAV） |
| `move(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 MOVE 路由（WebDAV） |
| `mkcol(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 MKCOL 路由（WebDAV） |
| `lock(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 LOCK 路由（WebDAV） |
| `unlock(path, handler)` | `path: string, handler: RequestHandler` | `void` | 注册 UNLOCK 路由（WebDAV） |

**中间件快捷方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `auto()` | - | `void` | 启用自动请求体解析 |
| `json()` | - | `void` | 启用 JSON 请求体解析 |
| `urlencoded()` | - | `void` | 启用 URL 编码请求体解析 |
| `multipart()` | - | `void` | 启用 multipart 表单解析 |
| `plain()` | - | `void` | 启用文本请求体解析 |
| `serveStatic(directoryPath, options?)` | `directoryPath: string, options?: CacheOptions` | `void` | 启用静态文件服务 |
| `cors(options?)` | `options?: CorsOptions` | `void` | 启用 CORS 跨域支持 |
| `logger(options?)` | `options?: LoggerOptions` | `void` | 启用日志中间件 |

**事件监听方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `onError(listener)` | `listener: ErrorEventListener` | `void` | 监听服务器错误事件 |
| `on(eventType, listener)` | `eventType: ServerEventType, listener: ServerEventListener` | `void` | 监听服务器事件 |
| `removeErrorListener(listener)` | `listener: ErrorEventListener` | `void` | 移除错误监听器 |
| `removeListener(eventType, listener)` | `eventType: ServerEventType, listener: ServerEventListener` | `void` | 移除事件监听器 |
| `removeAllListeners()` | - | `void` | 清除所有事件监听器 |

**服务器控制方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `startServer(port, address?)` | `port: number, address?: string` | `Promise<socket.NetAddress>` | 启动服务器 |
| `stopServer()` | - | `Promise<void>` | 停止服务器 |
| `getState()` | - | `Promise<socket.SocketStateBase \| undefined>` | 获取服务器运行状态 |

**客户端管理方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `getClientCount()` | - | `number` | 获取当前连接的客户端数量 |
| `getClients()` | - | `(TCPSocketConnection \| TLSSocketConnection)[]` | 获取所有客户端信息 |
| `getClient(clientId)` | `clientId: number` | `TCPSocketConnection \| TLSSocketConnection \| undefined` | 根据 ID 获取客户端信息 |
| `disconnectClient(clientId)` | `clientId: number` | `Promise<boolean>` | 断开指定客户端连接 |

**示例**

```typescript
const server = new HttpServer();

// 配置
server.setConfig('maxConnections', 100);

// 中间件
server.logger({ format: 'dev' });
server.cors({ origin: '*' });
server.auto();

// 路由
server.get('/api/users', async (req, res) => {
  res.json({ users: [] });
});

server.post('/api/users', async (req, res) => {
  const user = req.body;
  res.status(201).json({ created: user });
});

server.get('/api/users/:id', async (req, res) => {
  const id = req.params['id'];
  res.json({ id, name: 'User ' + id });
});

// 错误处理
server.use((err: Error, req: HttpRequest, res: HttpResponse, next: NextFunction) => {
  console.error('Error:', err);
  res.status(500).json({ error: err.message });
});

// 事件监听
server.onError((error) => {
  console.error('Server error:', error);
});

server.on(ServerEventType.REQUEST_RECEIVED, (event) => {
  console.log('Request received:', event.data);
});

// 启动
const info = await server.startServer(8080);
```

---

#### TLSServer

HTTPS 服务器类，继承自 HttpServer，提供 TLS 加密的 HTTP 服务。

**构造函数**

```typescript
constructor(options: socket.TLSSecureOptions)
```

**参数**
- `options` - TLS 配置选项，包含证书和私钥

**示例**

```typescript
import { TLSServer, CertManager } from '@handwer/webdav-server';

// 方式一：从文件加载证书
const tlsOptions = await CertManager.loadFromFiles(
  '/path/to/private.key',
  '/path/to/certificate.crt',
  '/path/to/ca.crt' // 可选
);

// 方式二：直接配置
const tlsOptions: socket.TLSSecureOptions = {
  key: '-----BEGIN PRIVATE KEY-----\n...',
  cert: '-----BEGIN CERTIFICATE-----\n...',
  ca: '-----BEGIN CERTIFICATE-----\n...' // 可选
};

const server = new TLSServer(tlsOptions);

// 其他配置同 HttpServer
server.get('/', async (req, res) => {
  res.json({ secure: true });
});

const info = await server.startServer(8443);
```

---

#### CertManager

SSL 证书管理工具类。

**静态方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `loadFromFiles(keyPath, certPath, caPath?)` | `keyPath: string, certPath: string, caPath?: string` | `Promise<socket.TLSSecureOptions>` | 从文件加载证书配置 |
| `validateConfig(options)` | `options: socket.TLSSecureOptions` | `boolean` | 验证证书配置 |

**示例**

```typescript
import { CertManager } from '@handwer/webdav-server';

// 加载证书
const tlsOptions = await CertManager.loadFromFiles(
  '/data/ssl/private.key',
  '/data/ssl/certificate.crt'
);

// 验证证书
if (CertManager.validateConfig(tlsOptions)) {
  console.log('Certificate is valid');
}
```

---

#### HttpRequest

HTTP 请求类，用于解析和处理 HTTP 请求数据。

**属性**

| 属性 | 类型 | 描述 |
|------|------|------|
| `method` | `string` | HTTP 请求方法（GET、POST 等） |
| `path` | `string` | 请求路径（不包含查询字符串） |
| `url` | `string` | 完整的 URL 路径（包含查询字符串） |
| `version` | `string` | HTTP 版本 |
| `ip` | `string` | 客户端 IP 地址 |
| `headers` | `Map<string, string>` | 请求头集合 |
| `body` | `ESObject` | 解析后的请求体数据 |
| `query` | `Map<string, string>` | 查询字符串参数 |
| `params` | `Record<string, string>` | 路由参数 |
| `files` | `Record<string, File \| UploadedFile>` | 上传的文件 |
| `userAgent` | `string` | User-Agent（getter） |
| `referer` | `string` | Referer（getter） |
| `contentLength` | `number` | Content-Length（getter） |

**方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `get(headerName)` | `headerName: string` | `string \| undefined` | 获取请求头 |
| `is(type)` | `type: string` | `boolean` | 检查是否为指定的 Content-Type |
| `parseBody()` | - | `void` | 解析请求体数据 |
| `getRawBody()` | - | `ArrayBuffer` | 获取原始请求体数据 |

**流式传输方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `enableStreaming()` | - | `HttpRequest` | 启用流式模式（支持链式调用） |
| `isStreamingEnabled()` | - | `boolean` | 检查是否启用了流式模式 |
| `onData(callback)` | `callback: DataCallback` | `void` | 注册数据回调 |
| `onEnd(callback)` | `callback: EndCallback` | `void` | 注册结束回调 |
| `onError(callback)` | `callback: ErrorCallback` | `void` | 注册错误回调 |
| `getReceivedBytes()` | - | `number` | 获取已接收的字节数 |
| `getExpectedBytes()` | - | `number` | 获取期望接收的总字节数 |
| `isComplete()` | - | `boolean` | 检查是否接收完毕 |

**示例**

```typescript
// 基本使用
server.post('/api/data', async (req: HttpRequest, res: HttpResponse) => {
  // 获取请求头
  const contentType = req.get('content-type');
  
  // 检查 Content-Type
  if (req.is('application/json')) {
    // req.body 已自动解析为 JSON 对象
    const data = req.body;
    res.json({ received: data });
  }
  
  // 获取查询参数
  const page = req.query.get('page') || '1';
  
  // 获取路由参数
  const id = req.params['id'];
  
  // 获取客户端 IP
  const clientIp = req.ip;
});

// 流式上传
server.put('/upload', async (req: HttpRequest, res: HttpResponse) => {
  req.enableStreaming();
  
  const chunks: ArrayBuffer[] = [];
  
  req.onData((chunk: ArrayBuffer) => {
    chunks.push(chunk);
    console.log(`Received ${req.getReceivedBytes()}/${req.getExpectedBytes()} bytes`);
  });
  
  req.onEnd(() => {
    console.log('Upload complete');
    res.status(201).send('OK');
  });
  
  req.onError((error) => {
    console.error('Upload error:', error);
    res.status(500).send('Error');
  });
});
```

---

#### HttpResponse

HTTP 响应类，用于构建和发送 HTTP 响应。

**方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `status(code)` | `code: number` | `HttpResponse` | 设置 HTTP 状态码（支持链式调用） |
| `getStatusCode()` | - | `number` | 获取当前状态码 |
| `setHeader(name, value)` | `name: string, value: string` | `HttpResponse` | 设置响应头（支持链式调用） |
| `getHeader(name)` | `name: string` | `string \| undefined` | 获取响应头 |
| `removeHeader(name)` | `name: string` | `HttpResponse` | 移除响应头（支持链式调用） |
| `isHeadersSent()` | - | `boolean` | 检查响应头是否已发送 |
| `isFinished()` | - | `boolean` | 检查响应是否已完成 |
| `onFinish(callback)` | `callback: ResponseFinishCallback` | `void` | 添加响应完成回调 |

**发送响应方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `send(body?)` | `body?: string \| ArrayBuffer` | `Promise<void>` | 发送响应数据 |
| `json(data)` | `data: ESObject` | `Promise<void>` | 发送 JSON 响应 |
| `xml(xmlString)` | `xmlString: string` | `Promise<void>` | 发送 XML 响应 |
| `multiStatus(data)` | `data: ESObject` | `Promise<void>` | 发送 207 Multi-Status 响应（WebDAV） |
| `multiJson(data)` | `data: ESObject` | `Promise<void>` | 发送 207 Multi-Status 响应（JSON 格式） |

**流式传输方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `write(chunk, encoding?)` | `chunk: string \| ArrayBuffer, encoding?: string` | `Promise<boolean>` | 写入数据块 |
| `end(chunk?, encoding?)` | `chunk?: string \| ArrayBuffer, encoding?: string` | `Promise<void>` | 结束响应 |

**文件传输方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `sendFile(filePath, options?)` | `filePath: string, options?: SendFileOptions` | `Promise<void>` | 流式发送文件，支持 Range 请求 |
| `setRequestHeaders(headers)` | `headers: Map<string, string>` | `void` | 设置请求头引用（用于 Range 请求） |

**示例**

```typescript
// 发送各种响应
server.get('/json', async (req, res) => {
  res.json({ message: 'Hello' });
});

server.get('/status', async (req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

server.get('/headers', async (req, res) => {
  res.setHeader('X-Custom-Header', 'value')
     .setHeader('Cache-Control', 'no-cache')
     .send('OK');
});

// 流式响应
server.get('/stream', async (req, res) => {
  res.setHeader('Content-Type', 'text/plain');
  
  for (let i = 0; i < 10; i++) {
    await res.write(`Line ${i}\n`);
  }
  
  await res.end();
});

// 发送文件
server.get('/download/:filename', async (req, res) => {
  const filename = req.params['filename'];
  res.setRequestHeaders(req.headers); // 支持 Range 请求
  await res.sendFile(`/data/files/${filename}`);
});

// Server-Sent Events
server.get('/sse', async (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  
  let id = 0;
  const interval = setInterval(async () => {
    await res.write(`data: ${JSON.stringify({ id, time: Date.now() })}\n\n`);
    id++;
  }, 1000);
  
  // 清理
  res.onFinish(() => {
    clearInterval(interval);
  });
});
```

---

#### Router

路由管理器类，负责路由的注册、匹配和执行。

**方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `addRoute(method, path, handler)` | `method: string, path: string, handler: RequestHandler \| ErrorHandler` | `void` | 添加路由 |
| `handle(req, res)` | `req: HttpRequest, res: HttpResponse` | `void` | 处理 HTTP 请求 |
| `getRoutes()` | - | `Route[]` | 获取所有路由 |

**Route 接口**

```typescript
interface Route {
  method: string;           // HTTP 方法
  path: string;             // 路由路径
  handler: RequestHandler | ErrorHandler; // 处理函数
  pathRegex: RegExp | null; // 路径正则表达式
  paramNames: string[];     // 参数名列表
}
```

**示例**

```typescript
import { Router, HttpRequest, HttpResponse, NextFunction } from '@handwer/webdav-server';

const router = new Router();

// 添加路由
router.addRoute('GET', '/users', async (req, res, next) => {
  res.json({ users: [] });
});

router.addRoute('GET', '/users/:id', async (req, res, next) => {
  const id = req.params['id'];
  res.json({ id });
});

// 查看所有路由
const routes = router.getRoutes();
routes.forEach(route => {
  console.log(`${route.method} ${route.path}`);
});
```

---

#### WebDAVServer

WebDAV 服务器类，提供高层级的 WebDAV 服务封装。

**构造函数**

```typescript
constructor(options?: WebDAVServerOptions)
```

**WebDAVServerOptions 接口**

```typescript
interface WebDAVServerOptions {
  port?: number;                    // 监听端口，默认 8080
  host?: string;                    // 监听地址
  enableAuth?: boolean;             // 是否启用身份验证
  username?: string;                // 用户名
  password?: string;                // 密码
  enableLogging?: boolean;          // 是否启用日志，默认 true
  logStream?: (message: string) => void;  // 自定义日志输出流
  logFormat?: string;               // 日志格式
}
```

**方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `mount(virtualPath, realPath)` | `virtualPath: string, realPath: string` | `void` | 挂载虚拟路径到物理路径 |
| `start()` | - | `Promise<socket.NetAddress \| null>` | 启动服务器 |
| `stop()` | - | `Promise<void>` | 停止服务器 |
| `setLogStream(logStream)` | `logStream: (message: string) => void` | `void` | 设置自定义日志输出流 |
| `getLogStream()` | - | `((message: string) => void) \| undefined` | 获取当前日志输出流 |

**支持的 WebDAV 方法**

- `OPTIONS` - 获取支持的方法
- `PROPFIND` - 获取属性
- `GET` - 下载文件
- `HEAD` - 获取文件信息
- `PUT` - 上传文件
- `DELETE` - 删除文件/目录
- `MKCOL` - 创建目录
- `MOVE` - 移动文件/目录
- `COPY` - 复制文件/目录

**示例**

```typescript
import { WebDAVServer } from '@handwer/webdav-server';

// 创建 WebDAV 服务器
const webdav = new WebDAVServer({
  port: 8080,
  enableLogging: true,
  logFormat: 'dev'
});

// 挂载路径
webdav.mount('/documents', '/data/storage/documents');
webdav.mount('/photos', '/data/media/photos');
webdav.mount('/backup', '/data/backup');

// 自定义日志输出
webdav.setLogStream((message: string) => {
  console.log(`[WebDAV] ${message}`);
  // 也可以写入文件或发送到远程日志服务器
});

// 启动服务器
const info = await webdav.start();
if (info) {
  console.log(`WebDAV server running at http://${info.address}:${info.port}`);
}

// 停止服务器
await webdav.stop();
```

---

#### ServerEventEmitter

服务器事件发射器类。

**方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `onError(listener)` | `listener: ErrorEventListener` | `void` | 监听错误事件 |
| `on(eventType, listener)` | `eventType: ServerEventType, listener: ServerEventListener` | `void` | 监听服务器事件 |
| `emitError(error, type)` | `error: Error, type: ServerErrorType` | `void` | 发射错误事件 |
| `emit(event)` | `event: ServerEvent` | `void` | 发射服务器事件 |
| `removeErrorListener(listener)` | `listener: ErrorEventListener` | `void` | 移除错误监听器 |
| `removeListener(eventType, listener)` | `eventType: ServerEventType, listener: ServerEventListener` | `void` | 移除事件监听器 |
| `removeAllListeners()` | - | `void` | 清除所有监听器 |

---

### 中间件

#### BodyParser

请求体解析中间件，提供各种格式的请求体解析。

**静态方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `json()` | - | `RequestHandler` | JSON 解析中间件 |
| `urlencoded()` | - | `RequestHandler` | URL 编码解析中间件 |
| `multipart()` | - | `RequestHandler` | multipart 表单解析中间件 |
| `plain()` | - | `RequestHandler` | 文本解析中间件 |
| `auto()` | - | `RequestHandler` | 通用解析中间件（自动检测 Content-Type） |

**示例**

```typescript
// 方式一：使用服务器快捷方法
server.json();       // 只解析 JSON
server.urlencoded(); // 只解析 URL 编码
server.multipart();  // 只解析 multipart
server.plain();      // 只解析纯文本
server.auto();       // 自动检测并解析

// 方式二：使用中间件
import { BodyParser } from '@handwer/webdav-server';

server.use(BodyParser.json());
server.use(BodyParser.urlencoded());
```

---

#### Cors

CORS 跨域资源共享中间件。

**静态方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `create(options?)` | `options?: CorsOptions` | `RequestHandler` | 创建 CORS 中间件 |

**CorsOptions 接口**

```typescript
interface CorsOptions {
  methods?: string[];        // 允许的方法
  origin?: string | string[]; // 允许的源地址
  allowedHeaders?: string[]; // 允许的 header
}
```

**示例**

```typescript
// 方式一：使用服务器快捷方法
server.cors(); // 允许所有来源

server.cors({
  origin: 'https://example.com',
  methods: ['GET', 'POST', 'PUT'],
  allowedHeaders: ['Content-Type', 'Authorization']
});

// 方式二：使用中间件
import { Cors } from '@handwer/webdav-server';

server.use(Cors.create({
  origin: ['https://example.com', 'https://app.example.com'],
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Custom-Header']
}));
```

---

#### StaticFiles

静态文件服务中间件。

**静态方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `serve(directoryPath, options?)` | `directoryPath: string, options?: CacheOptions` | `RequestHandler` | 创建静态文件服务中间件 |

**CacheOptions 接口**

```typescript
interface CacheOptions {
  maxAge?: number; // 缓存最大时间（秒），默认 3600
}
```

**示例**

```typescript
// 方式一：使用服务器快捷方法
server.serveStatic('/data/www');

server.serveStatic('/data/www', { maxAge: 86400 }); // 缓存 1 天

// 方式二：使用中间件
import { StaticFiles } from '@handwer/webdav-server';

server.use(StaticFiles.serve('/data/www', { maxAge: 3600 }));
```

---

#### Logger

日志记录中间件。

**静态方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `create(options?)` | `options?: LoggerOptions` | `RequestHandler` | 创建日志中间件 |
| `dev()` | - | `RequestHandler` | 开发环境日志格式 |
| `combined()` | - | `RequestHandler` | Apache combined 格式 |
| `common()` | - | `RequestHandler` | Apache common 格式 |
| `short()` | - | `RequestHandler` | 简短格式 |
| `tiny()` | - | `RequestHandler` | 最简格式 |

**LoggerOptions 接口**

```typescript
interface LoggerOptions {
  format?: LogFormat | string; // 日志格式
  skip?: (req: HttpRequest, res: HttpResponse) => boolean; // 跳过条件
  stream?: (message: string) => void; // 输出流
}
```

**LogFormat 枚举**

```typescript
enum LogFormat {
  COMBINED = 'combined', // Apache combined 格式
  COMMON = 'common',     // Apache common 格式
  DEV = 'dev',           // 开发环境格式
  SHORT = 'short',       // 简短格式
  TINY = 'tiny'          // 最简格式
}
```

**示例**

```typescript
// 方式一：使用服务器快捷方法
server.logger(); // 默认 dev 格式

server.logger({ format: 'combined' });

server.logger({
  format: 'dev',
  skip: (req, res) => req.path.startsWith('/health'),
  stream: (msg) => console.log(msg.trim())
});

// 方式二：使用中间件
import { Logger, LogFormat } from '@handwer/webdav-server';

server.use(Logger.dev());
server.use(Logger.combined());
server.use(Logger.create({
  format: LogFormat.COMBINED,
  stream: (msg) => {
    // 写入文件或发送到远程日志服务器
  }
}));
```

---

#### FileUpload

文件上传中间件。

**静态方法**

| 方法 | 参数 | 返回值 | 描述 |
|------|------|--------|------|
| `create(options?)` | `options?: FileUploadOptions` | `RequestHandler` | 创建文件上传中间件 |

**FileUploadOptions 接口**

```typescript
interface FileUploadOptions {
  createParentPath?: boolean;  // 自动创建父目录，默认 false
  uriDecodeFileNames?: boolean; // 解码文件名，默认 false
  safeFileNames?: boolean;     // 安全文件名，默认 false
  preserveExtension?: boolean; // 保留文件扩展名，默认 false
  abortOnLimit?: boolean;      // 超过限制时中止，默认 false
  useTempFiles?: boolean;      // 使用临时文件，默认 true
  tempFileDir?: string;        // 临时文件目录，默认 '/tmp/uploads'
  debug?: boolean;             // 调试模式，默认 false
  limits?: FileLimits;         // 文件限制
}
```

**FileLimits 接口**

```typescript
interface FileLimits {
  fileSize?: number;   // 单个文件最大大小（字节），默认 50MB
  files?: number;      // 最大文件数量，默认 10
  fields?: number;     // 最大字段数量，默认 100
  fieldSize?: number;  // 字段最大大小，默认 1MB
}
```

**UploadedFile 接口**

```typescript
interface UploadedFile {
  name: string;              // 原始文件名
  data: ArrayBuffer;         // 文件数据
  size: number;              // 文件大小
  encoding: string;          // 编码
  tempFilePath: string;      // 临时文件路径
  truncated: boolean;        // 是否被截断
  mimetype: string;          // MIME 类型
  md5?: string;              // MD5 哈希
  mv: (path: string) => Promise<void>; // 移动文件方法
}
```

**示例**

```typescript
import { FileUpload } from '@handwer/webdav-server';

// 使用文件上传中间件
server.use(FileUpload.create({
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
    files: 5
  },
  useTempFiles: true,
  tempFileDir: '/tmp/uploads',
  createParentPath: true
}));

server.post('/upload', async (req, res) => {
  // 获取上传的文件
  const file = req.files['file'] as UploadedFile;
  
  if (file) {
    console.log('File name:', file.name);
    console.log('File size:', file.size);
    console.log('MIME type:', file.mimetype);
    
    // 移动文件到目标位置
    await file.mv('/data/uploads/' + file.name);
    
    res.json({
      success: true,
      filename: file.name,
      size: file.size
    });
  } else {
    res.status(400).json({ error: 'No file uploaded' });
  }
});
```

---

### 类型定义

#### 函数类型

```typescript
// 下一步函数类型
type NextFunction = (error?: Error) => void;

// 请求处理函数类型
type RequestHandler = (req: HttpRequest, res: HttpResponse, next: NextFunction) => void;

// 错误处理函数类型
type ErrorHandler = (error: Error, req: HttpRequest, res: HttpResponse, next: NextFunction) => void;

// 数据回调函数类型
type DataCallback = (chunk: ArrayBuffer) => void;

// 结束回调函数类型
type EndCallback = () => void;

// 错误回调函数类型
type ErrorCallback = (error: BusinessError) => void;

// 响应完成回调函数类型
type ResponseFinishCallback = (statusCode: number, responseSize: number) => void;

// 错误事件监听器类型
type ErrorEventListener = (error: ServerError) => void;

// 服务器事件监听器类型
type ServerEventListener = (event: ServerEvent) => void;
```

#### 接口定义

```typescript
// 上传文件接口
interface File {
  fieldName: string;   // 表单字段名
  fileName: string;    // 文件名
  contentType: string; // 文件类型
  data: ArrayBuffer;   // 文件数据
  name?: string;       // 兼容 UploadedFile
  size?: number;       // 兼容 UploadedFile
  mimetype?: string;   // 兼容 UploadedFile
}

// CORS 配置选项接口
interface CorsOptions {
  methods?: string[];         // 允许的方法
  origin?: string | string[]; // 允许的源地址
  allowedHeaders?: string[];  // 允许的 header
}

// 缓存配置选项接口
interface CacheOptions {
  maxAge?: number; // 缓存最大时间（秒）
}

// 服务器错误信息接口
interface ServerError {
  type: ServerErrorType;
  error?: Error;
}

// 服务器事件信息接口
interface ServerEvent {
  type: ServerEventType;
  data?: ESObject;
}

// WebDAV 服务器配置接口
interface WebDAVServerOptions {
  port?: number;
  host?: string;
  enableAuth?: boolean;
  username?: string;
  password?: string;
  enableLogging?: boolean;
  logStream?: (message: string) => void;
  logFormat?: string;
}

// 路径映射接口
interface PathMapping {
  virtualPath: string; // 虚拟路径
  realPath: string;    // 物理路径
}

// 文件/目录信息接口
interface FileInfo {
  name: string;         // 文件名
  path: string;         // 完整路径
  isDirectory: boolean; // 是否为目录
  size: number;         // 文件大小（字节）
  lastModified: number; // 最后修改时间（时间戳）
  createdTime: number;  // 创建时间（时间戳）
  mimeType?: string;    // MIME 类型
}
```

#### 枚举定义

```typescript
// 服务器错误类型枚举
enum ServerErrorType {
  STARTUP_FAILED = 'startup_failed',
  CONNECTION_ERROR = 'connection_error',
  CLIENT_ERROR = 'client_error',
  SOCKET_ERROR = 'socket_error',
  LISTEN_ERROR = 'listen_error',
  BIND_ERROR = 'bind_error',
  CERTIFICATE_ERROR = 'certificate_error',
  TLS_ERROR = 'tls_error',
  UNKNOWN_ERROR = 'unknown_error'
}

// 服务器事件类型枚举
enum ServerEventType {
  SERVER_STARTED = 'server_started',
  SERVER_STOPPED = 'server_stopped',
  ERROR = 'error',
  WARNING = 'warning',
  REQUEST_RECEIVED = 'request_received',
  RESPONSE_SENT = 'response_sent'
}

// 日志格式枚举
enum LogFormat {
  COMBINED = 'combined',
  COMMON = 'common',
  DEV = 'dev',
  SHORT = 'short',
  TINY = 'tiny'
}
```

---

## 示例

项目包含完整的示例代码，位于 `entry/src/main/ets/examples/` 目录：

| 示例 | 描述 | 端口 |
|------|------|------|
| [http](entry/src/main/ets/examples/http/) | 基础 HTTP 服务器 | 8080 |
| [https](entry/src/main/ets/examples/https/) | HTTPS/TLS 安全连接 | 8443 |
| [body-parser](entry/src/main/ets/examples/body-parser/) | 请求体解析 | 8080 |
| [cors](entry/src/main/ets/examples/cors/) | CORS 跨域 | 8080 |
| [router](entry/src/main/ets/examples/router/) | 路由系统 | 8080 |
| [static](entry/src/main/ets/examples/static/) | 静态文件服务 | 8080 |
| [logger](entry/src/main/ets/examples/logger/) | 日志记录 | 8080 |
| [file-upload](entry/src/main/ets/examples/file-upload/) | 文件上传 | 8080 |
| [stream](entry/src/main/ets/examples/stream/) | 流式传输 | 8080 |
| [upload](entry/src/main/ets/examples/upload/) | 分片上传 | 8080 |
| [event](entry/src/main/ets/examples/event/) | 事件系统 | 8080 |
| [webdav](entry/src/main/ets/examples/webdav/) | WebDAV 服务器 | 8080 |

---

## 许可证

[Apache-2.0](LICENSE)

---

## 作者

@handwer

## 主页

[https://github.com/iHongRen](https://github.com/iHongRen)

## 仓库

[https://github.com/iHongRen/WebServer](https://github.com/iHongRen/WebServer)
