/**
 * @fileName : WebDAVServer.ets
 * @author : @cxy
 * @date : 2025/3/24
 * @description : WebDAV服务器 - 高层级封装
 */

import { HttpServer, HttpRequest, HttpResponse } from '../Index';
import { socket } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { FileSystemAdapter, FileInfo } from './FileSystemAdapter';
import { Utils } from '../Utils';
import { ObjectSpread } from './ObjectSpread';

/**
 * WebDAV服务器配置
 */
export interface WebDAVServerOptions {
  port?: number;                    // 监听端口
  host?: string;                    // 监听地址
  enableAuth?: boolean;             // 是否启用身份验证
  username?: string;                // 用户名
  password?: string;                // 密码
  enableLogging?: boolean;          // 是否启用日志
}

/**
 * 路径映射
 */
export interface PathMapping {
  virtualPath: string;              // 虚拟路径（如 /photos）
  realPath: string;                 // 物理路径（如 /data/data/.../albums）
}

/**
 * WebDAV服务器类
 * 提供高层级的WebDAV服务封装
 */
export class WebDAVServer {
  private server: HttpServer;
  private options: WebDAVServerOptions;
  private pathMappings: Map<string, PathMapping> = new Map();
  private isRunning: boolean = false;

  /**
   * 构造函数
   * @param options 配置选项
   */
  constructor(options: WebDAVServerOptions = {}) {
    this.options = ObjectSpread({
      port: 8080,
      host: '',
      enableAuth: false,
      enableLogging: true,
    }, options)
    this.server = new HttpServer();
    this.setupMiddleware();
    this.setupRoutes();
  }

  /**
   * 挂载虚拟路径到物理路径
   * @param virtualPath 虚拟路径（如 /photos）
   * @param realPath 物理路径（如 /data/data/.../albums）
   */
  public mount(virtualPath: string, realPath: string): void {
    // 规范化路径
    const normalizedVirtual = FileSystemAdapter.normalizePath(virtualPath);
    const normalizedReal = realPath.replace(/\/+$/, ''); // 移除尾部斜杠

    this.pathMappings.set(normalizedVirtual, {
      virtualPath: normalizedVirtual,
      realPath: normalizedReal
    });

    console.log(`[WebDAV] 挂载路径: ${normalizedVirtual} -> ${normalizedReal}`);
  }

  /**
   * 启动服务器
   */
  public async start(): Promise<socket.NetAddress | null> {
    if (this.isRunning) {
      console.warn('[WebDAV] 服务器已在运行');
      return null;
    }

    try {
      const info = await this.server.startServer(this.options.port!, this.options.host);
      if (info) {
        this.isRunning = true;
        console.log(`[WebDAV] 服务器启动成功`);
        console.log(`[WebDAV] 监听地址: http://${info.address}:${info.port}`);
        this.printMountInfo(info);
        return info;
      }
      return null;
    } catch (error) {
      console.error('[WebDAV] 服务器启动失败:', error);
      return null;
    }
  }

  /**
   * 停止服务器
   */
  public async stop(): Promise<void> {
    if (!this.isRunning) {
      return;
    }

    await this.server.stopServer();
    this.isRunning = false;
    console.log('[WebDAV] 服务器已停止');
  }

  /**
   * 配置中间件
   */
  private setupMiddleware(): void {
    // 日志中间件
    if (this.options.enableLogging) {
      this.server.logger({
        format: 'dev',
        stream: (log: string) => {
          console.log(`[WebDAV] ${log}`);
        }
      });
    }

    // CORS中间件
    this.server.cors({
      origin: '*',
      methods: ['GET','POST','PUT','DELETE','OPTIONS','HEAD','MKCOL','PROPFIND','PROPPATCH','COPY','MOVE','LOCK','UNLOCK'],
      allowedHeaders: ['Content-Type','Authorization','Depth','Destination','Overwrite','If','Lock-Token'],
    });
  }

  /**
   * 配置路由
   */
  private setupRoutes(): void {
    // OPTIONS - 全局响应
    this.server.options('*', async (req: HttpRequest, res: HttpResponse) => {
      await this.handleOptions(req, res);
    });

    // PROPFIND - 获取属性
    this.server.propfind('*', async (req: HttpRequest, res: HttpResponse) => {
      await this.handlePropfind(req, res);
    });

    // GET - 下载文件
    this.server.get('*', async (req: HttpRequest, res: HttpResponse) => {
      await this.handleGet(req, res);
    });

    // HEAD - 获取文件信息
    this.server.head('*', async (req: HttpRequest, res: HttpResponse) => {
      await this.handleHead(req, res);
    });

    // PUT - 上传文件
    this.server.put('*', async (req: HttpRequest, res: HttpResponse) => {
      await this.handlePut(req, res);
    });

    // DELETE - 删除文件/目录
    this.server.delete('*', async (req: HttpRequest, res: HttpResponse) => {
      await this.handleDelete(req, res);
    });

    // MKCOL - 创建目录
    this.server.mkcol('*', async (req: HttpRequest, res: HttpResponse) => {
      await this.handleMkcol(req, res);
    });

    // MOVE - 移动文件/目录
    this.server.move('*', async (req: HttpRequest, res: HttpResponse) => {
      await this.handleMove(req, res);
    });

    // COPY - 复制文件/目录
    this.server.copy('*', async (req: HttpRequest, res: HttpResponse) => {
      await this.handleCopy(req, res);
    });
  }

  // ==================== 请求处理方法 ====================

  /**
   * 处理OPTIONS请求
   */
  private async handleOptions(req: HttpRequest, res: HttpResponse): Promise<void> {
    res.setHeader('DAV', '1, 2');
    res.setHeader('Allow', 'GET, POST, OPTIONS, HEAD, MKCOL, PUT, DELETE, PROPFIND, PROPPATCH, COPY, MOVE, LOCK, UNLOCK');
    res.setHeader('MS-Author-Via', 'DAV');
    res.setHeader('Content-Length', '0');
    res.status(200).send();
  }

  /**
   * 处理PROPFIND请求
   */
  private async handlePropfind(req: HttpRequest, res: HttpResponse): Promise<void> {
    const GeneratedDestructObj_1 = this.resolvePath(req.path);
    const virtualPath = GeneratedDestructObj_1.virtualPath;
    const realPath = GeneratedDestructObj_1.realPath;
    const mapping = GeneratedDestructObj_1.mapping;
    
    if (!mapping) {
      res.status(404).json({ error: 'Not Found' });
      return;
    }

    // 安全检查
    if (!this.isPathSafe(realPath, mapping.realPath)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const depth = req.headers.get('depth') || 'infinity';
    const exists = await FileSystemAdapter.exists(realPath);

    if (!exists) {
      res.status(404).json({ error: 'Not Found' });
      return;
    }

    const fileInfo = await FileSystemAdapter.stat(realPath);
    if (!fileInfo) {
      res.status(404).json({ error: 'Not Found' });
      return;
    }

    // 构建响应
    const responses: WebDAVResponse[] = [];

    // 添加当前资源
    responses.push(this.buildPropfindResponse(virtualPath, fileInfo));

    // 如果是目录且depth不为0，添加子资源
    if (fileInfo.isDirectory && depth !== '0') {
      const children = await FileSystemAdapter.listDir(realPath);
      for (const child of children) {
        const childVirtualPath = virtualPath === '/' 
          ? `/${child.name}` 
          : `${virtualPath}/${child.name}`;
        responses.push(this.buildPropfindResponse(childVirtualPath, child));
      }
    }

    await res.multiStatus({ responses });
  }

  /**
   * 处理GET请求
   */
  private async handleGet(req: HttpRequest, res: HttpResponse): Promise<void> {
    const GeneratedDestructObj_1 = this.resolvePath(req.path);
    const virtualPath = GeneratedDestructObj_1.virtualPath;
    const realPath = GeneratedDestructObj_1.realPath;
    const mapping = GeneratedDestructObj_1.mapping;
    
    if (!mapping) {
      res.status(404).json({ error: 'Not Found' });
      return;
    }

    if (!this.isPathSafe(realPath, mapping.realPath)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const exists = await FileSystemAdapter.exists(realPath);
    if (!exists) {
      res.status(404).json({ error: 'Not Found' });
      return;
    }

    const fileInfo = await FileSystemAdapter.stat(realPath);
    if (!fileInfo) {
      res.status(404).json({ error: 'Not Found' });
      return;
    }

    if (fileInfo.isDirectory) {
      // 目录：返回列表
      const children = await FileSystemAdapter.listDir(realPath);
      const items: DirListItem[] = [];
      for (const c of children) {
        const item: DirListItem = {
          name: c.name,
          isDirectory: c.isDirectory,
          size: c.size,
          lastModified: c.lastModified
        };
        items.push(item);
      }
      res.json({
        path: virtualPath,
        type: 'directory',
        items: items
      } as ESObject);
    } else {
      // 文件：使用sendFile发送
      res.setRequestHeaders(req.headers);
      await res.sendFile(realPath);
    }
  }

  /**
   * 处理HEAD请求
   */
  private async handleHead(req: HttpRequest, res: HttpResponse): Promise<void> {
    const pathResult = this.resolvePath(req.path);
    const virtualPath = pathResult.virtualPath;
    const realPath = pathResult.realPath;
    const mapping = pathResult.mapping;
    
    if (!mapping || !this.isPathSafe(realPath, mapping.realPath)) {
      res.status(404).send();
      return;
    }

    const fileInfo = await FileSystemAdapter.stat(realPath);
    if (!fileInfo) {
      res.status(404).send();
      return;
    }

    res.setHeader('Content-Type', fileInfo.mimeType || 'application/octet-stream');
    res.setHeader('Content-Length', fileInfo.size.toString());
    res.setHeader('Last-Modified', new Date(fileInfo.lastModified).toUTCString());
    res.status(200).send();
  }

  /**
   * 处理PUT请求
   */
  private async handlePut(req: HttpRequest, res: HttpResponse): Promise<void> {
    const pathResult = this.resolvePath(req.path);
    const virtualPath = pathResult.virtualPath;
    const realPath = pathResult.realPath;
    const mapping = pathResult.mapping;
    
    if (!mapping) {
      res.status(404).json({ error: 'Not Found' } as ESObject);
      return;
    }

    if (!this.isPathSafe(realPath, mapping.realPath)) {
      res.status(403).json({ error: 'Forbidden' } as ESObject);
      return;
    }

    // 启用流式模式
    req.enableStreaming();

    // 确保父目录存在
    const parentDir = realPath.substring(0, realPath.lastIndexOf('/'));
    const parentExists = await FileSystemAdapter.exists(parentDir);
    if (!parentExists) {
      await FileSystemAdapter.mkdir(parentDir);
    }

    // 打开文件用于写入
    const file = await fileIo.open(realPath, 
      fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);

    let receivedBytes = 0;

    req.onData(async (chunk: ArrayBuffer) => {
      await fileIo.write(file.fd, chunk);
      receivedBytes += chunk.byteLength;
    });

    req.onEnd(async () => {
      await fileIo.close(file.fd);
      res.setHeader('Content-Length', '0');
      res.status(201).send(); // Created
    });

    req.onError(async (error) => {
      await fileIo.close(file.fd);
      res.status(500).json({ error: 'Upload failed' } as ESObject);
    });
  }

  /**
   * 处理DELETE请求
   */
  private async handleDelete(req: HttpRequest, res: HttpResponse): Promise<void> {
    const pathResult = this.resolvePath(req.path);
    const virtualPath = pathResult.virtualPath;
    const realPath = pathResult.realPath;
    const mapping = pathResult.mapping;
    
    if (!mapping || !this.isPathSafe(realPath, mapping.realPath)) {
      res.status(404).json({ error: 'Not Found' } as ESObject);
      return;
    }

    const exists = await FileSystemAdapter.exists(realPath);
    if (!exists) {
      res.status(404).json({ error: 'Not Found' } as ESObject);
      return;
    }

    const fileInfo = await FileSystemAdapter.stat(realPath);
    if (!fileInfo) {
      res.status(404).json({ error: 'Not Found' } as ESObject);
      return;
    }

    let success: boolean;
    if (fileInfo.isDirectory) {
      success = await FileSystemAdapter.rmdir(realPath);
    } else {
      success = await FileSystemAdapter.unlink(realPath);
    }

    if (success) {
      res.status(204).send(); // No Content
    } else {
      res.status(500).json({ error: 'Delete failed' } as ESObject);
    }
  }

  /**
   * 处理MKCOL请求
   */
  private async handleMkcol(req: HttpRequest, res: HttpResponse): Promise<void> {
    const pathResult = this.resolvePath(req.path);
    const virtualPath = pathResult.virtualPath;
    const realPath = pathResult.realPath;
    const mapping = pathResult.mapping;
    
    if (!mapping || !this.isPathSafe(realPath, mapping.realPath)) {
      res.status(403).json({ error: 'Forbidden' } as ESObject);
      return;
    }

    const exists = await FileSystemAdapter.exists(realPath);
    if (exists) {
      res.status(405).json({ error: 'Method Not Allowed' } as ESObject);
      return;
    }

    const success = await FileSystemAdapter.mkdir(realPath);
    if (success) {
      res.status(201).send(); // Created
    } else {
      res.status(500).json({ error: 'Create directory failed' } as ESObject);
    }
  }

  /**
   * 处理MOVE请求
   */
  private async handleMove(req: HttpRequest, res: HttpResponse): Promise<void> {
    const srcPathResult = this.resolvePath(req.path);
    const srcVirtual = srcPathResult.virtualPath;
    const srcReal = srcPathResult.realPath;
    const srcMapping = srcPathResult.mapping;
    const destination = req.headers.get('destination');

    if (!srcMapping || !this.isPathSafe(srcReal, srcMapping.realPath)) {
      res.status(403).json({ error: 'Forbidden' } as ESObject);
      return;
    }

    if (!destination) {
      res.status(400).json({ error: 'Missing Destination header' } as ESObject);
      return;
    }

    // 解析目标路径
    const destUrl = this.parseDestinationUrl(destination);
    const destPathResult = this.resolvePath(destUrl);
    const destVirtual = destPathResult.virtualPath;
    const destReal = destPathResult.realPath;
    const destMapping = destPathResult.mapping;

    if (!destMapping || !this.isPathSafe(destReal, destMapping.realPath)) {
      res.status(403).json({ error: 'Forbidden destination' } as ESObject);
      return;
    }

    const success = await FileSystemAdapter.move(srcReal, destReal);
    if (success) {
      res.status(201).send(); // Created
    } else {
      res.status(500).json({ error: 'Move failed' } as ESObject);
    }
  }

  /**
   * 处理COPY请求
   */
  private async handleCopy(req: HttpRequest, res: HttpResponse): Promise<void> {
    const srcPathResult = this.resolvePath(req.path);
    const srcVirtual = srcPathResult.virtualPath;
    const srcReal = srcPathResult.realPath;
    const srcMapping = srcPathResult.mapping;
    const destination = req.headers.get('destination');

    if (!srcMapping || !this.isPathSafe(srcReal, srcMapping.realPath)) {
      res.status(403).json({ error: 'Forbidden' } as ESObject);
      return;
    }

    if (!destination) {
      res.status(400).json({ error: 'Missing Destination header' } as ESObject);
      return;
    }

    const destUrl = this.parseDestinationUrl(destination);
    const destPathResult = this.resolvePath(destUrl);
    const destVirtual = destPathResult.virtualPath;
    const destReal = destPathResult.realPath;
    const destMapping = destPathResult.mapping;

    if (!destMapping || !this.isPathSafe(destReal, destMapping.realPath)) {
      res.status(403).json({ error: 'Forbidden destination' } as ESObject);
      return;
    }

    const success = await FileSystemAdapter.copy(srcReal, destReal);
    if (success) {
      res.status(201).send(); // Created
    } else {
      res.status(500).json({ error: 'Copy failed' } as ESObject);
    }
  }

  // ==================== 辅助方法 ====================

  /**
   * 解析路径：将虚拟路径转换为物理路径
   */
  private resolvePath(requestPath: string): ResolvePathResult {
    const normalizedPath = FileSystemAdapter.normalizePath(requestPath);
    
    // 查找匹配的映射
    let bestMatch: PathMapping | null = null;
    let bestMatchLength = 0;

    for (const entry of this.pathMappings) {
      const mapping = entry[1];
      if (normalizedPath.startsWith(mapping.virtualPath)) {
        if (mapping.virtualPath.length > bestMatchLength) {
          bestMatch = mapping;
          bestMatchLength = mapping.virtualPath.length;
        }
      }
    }

    if (!bestMatch) {
      const result: ResolvePathResult = {
        virtualPath: normalizedPath,
        realPath: '',
        mapping: null
      };
      return result;
    }

    // 计算相对路径
    const relativePath = normalizedPath.substring(bestMatch.virtualPath.length);
    const realPath = relativePath 
      ? FileSystemAdapter.joinPath(bestMatch.realPath, relativePath)
      : bestMatch.realPath;

    const result: ResolvePathResult = {
      virtualPath: normalizedPath,
      realPath: realPath,
      mapping: bestMatch
    };
    return result;
  }

  /**
   * 检查路径是否安全（防止目录遍历攻击）
   */
  private isPathSafe(realPath: string, basePath: string): boolean {
    const normalizedReal = FileSystemAdapter.normalizePath(realPath);
    const normalizedBase = FileSystemAdapter.normalizePath(basePath);
    
    return normalizedReal.startsWith(normalizedBase);
  }

  /**
   * 解析Destination URL
   */
  private parseDestinationUrl(destination: string): string {
    try {
      // 移除协议和主机部分
      const urlMatch = destination.match(/^https?:\/\/[^\/]+(\/.*)$/);
      if (urlMatch) {
        return urlMatch[1];
      }
      return destination;
    } catch (error) {
      return destination;
    }
  }

  /**
   * 构建PROPFIND响应
   */
  private buildPropfindResponse(href: string, fileInfo: FileInfo): WebDAVResponse {
    const prop: Record<string, string> = {
      'displayname': fileInfo.name,
      'getcontentlength': fileInfo.size.toString(),
      'getlastmodified': new Date(fileInfo.lastModified).toUTCString(),
      'creationdate': new Date(fileInfo.createdTime).toUTCString(),
      'resourcetype': fileInfo.isDirectory ? '<D:collection/>' : '',
      'getcontenttype': fileInfo.mimeType || 'application/octet-stream'
    };
    const propstat: PropStat = {
      status: 'HTTP/1.1 200 OK',
      prop: prop
    };
    const response: WebDAVResponse = {
      href: href,
      propstat: propstat
    };
    return response;
  }

  /**
   * 打印挂载信息
   */
  private printMountInfo(info: socket.NetAddress): void {
    console.log('\n[WebDAV] 挂载点:');
    console.log('='.repeat(60));
    
    for (const entry of this.pathMappings) {
      const mapping = entry[1];
      console.log(`  ${mapping.virtualPath} -> ${mapping.realPath}`);
    }
    
    console.log('\n[WebDAV] 支持的方法:');
    console.log('  OPTIONS, PROPFIND, GET, HEAD, PUT, DELETE, MKCOL, MOVE, COPY');
    console.log('='.repeat(60));
  }
}

/**
 * 路径解析结果
 */
interface ResolvePathResult {
  virtualPath: string;
  realPath: string;
  mapping: PathMapping | null;
}

/**
 * 目录列表项
 */
interface DirListItem {
  name: string;
  isDirectory: boolean;
  size: number;
  lastModified: number;
}

/**
 * PropStat接口
 */
interface PropStat {
  status: string;
  prop: Record<string, string>;
}

/**
 * WebDAV响应接口
 */
interface WebDAVResponse {
  href: string;
  propstat?: PropStat;
  status?: string;
}
