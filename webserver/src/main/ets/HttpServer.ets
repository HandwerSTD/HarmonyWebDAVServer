/**
 * @fileName : HttpServer.ets
 * @author : @cxy
 * @date : 2025/8/15
 * @description : Http服务器
 */

import { connection, socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Utils } from './Utils';
import { HttpRequest } from './HttpRequest';
import { HttpResponse } from './HttpResponse';
import { Router } from './Router';
import { LoggerOptions } from './middleware/logger';
import { deviceInfo } from '@kit.BasicServicesKit';

import {
  NextFunction,
  RequestHandler,
  ErrorHandler,
  CorsOptions,
  CacheOptions,
  BodyParser,
  Cors,
  StaticFiles,
  Logger,
} from './middleware';
import {
  ServerEventEmitter,
  ServerEvent,
  ServerErrorType,
  ServerEventType,
  ErrorEventListener,
  ServerEventListener
} from './ServerEvents';
import { util } from '@kit.ArkTS';

/**
 * 客户端连接状态枚举
 */
 enum ClientState {
  WAITING_HEADER,    // 等待接收完整的HTTP头部
  STREAMING_BODY     // 正在流式接收Body数据
}

/**
 * 客户端连接上下文
 */
 interface ClientContext {
  state: ClientState;                    // 当前状态
  buffer: ArrayBuffer;                   // 统一的数据缓冲区（用于所有数据）
  req: HttpRequest | null;               // 已创建的请求对象
  res: HttpResponse | null;              // 已创建的响应对象
  contentLength: number;                 // 期望的Body长度
  receivedBodyLength: number;            // 已接收的Body长度
  isChunked: boolean;                    // 是否为分块传输
}
/**
 * Http 服务器类
 * 提供HTTP服务器功能，支持路由、中间件等特性
 */
interface HttpChunkedData {
  chunks: ArrayBuffer[];
  remaining: ArrayBuffer;
}

interface HttpServerChunkedData {
  chunks: ArrayBuffer[];
  remaining: ArrayBuffer;
  isComplete: boolean;
}

export class HttpServer {
  protected router: Router = new Router(); // 路由管理器
  protected configs: Map<string, Object> = new Map(); // 配置存储
  protected clients: Map<number, socket.TCPSocketConnection | socket.TLSSocketConnection> = new Map(); // 客户端连接映射
  protected tcpServer: socket.TCPSocketServer | null = null; // TCP服务器实例
  protected eventEmitter: ServerEventEmitter = new ServerEventEmitter(); // 事件发射器

  /**
   * 构造函数
   * 初始化服务器并设置默认404处理
   */
  constructor() {
    this.use404()
  }

  /**
   * 设置配置项
   * @param key 配置键
   * @param value 配置值
   */
  public setConfig(key: string, value: Object) {
    this.configs.set(key, value);
  }

  /**
   * 获取配置项
   * @param key 配置键
   * @returns 配置值
   */
  public getConfig(key: string): Object | undefined {
    return this.configs.get(key);
  }

  /**
   *  默认404处理，需作为最后一个中间件
   */
  public use404() {
    this.use((req: HttpRequest, res: HttpResponse, _: NextFunction) => {
      if (!res.isHeadersSent()) {
        res.status(404).json({ error: 'Not Found', path: req.path });
      }
    });
  }

  /**
   * 注册中间件或错误处理中间件
   * @param handler 处理函数
   */
  public use(handler: RequestHandler | ErrorHandler) {
    this.router.addRoute('ANY', '*', handler);
  }

  /**
   * 注册GET路由
   * @param path 路由路径
   * @param handler 处理函数
   */
  public get(path: string, handler: RequestHandler) {
    this.router.addRoute('GET', path, handler);
  }

  /**
   * 注册POST路由
   * @param path 路由路径
   * @param handler 处理函数
   */
  public post(path: string, handler: RequestHandler) {
    this.router.addRoute('POST', path, handler);
  }

  /**
   * 注册PUT路由
   * @param path 路由路径
   * @param handler 处理函数
   */
  public put(path: string, handler: RequestHandler) {
    this.router.addRoute('PUT', path, handler);
  }

  /**
   * 注册DELETE路由
   * @param path 路由路径
   * @param handler 处理函数
   */
  public delete(path: string, handler: RequestHandler) {
    this.router.addRoute('DELETE', path, handler);
  }

  /**
   * 注册PROPFIND路由（WebDAV）
   * @param path 路由路径
   * @param handler 处理函数
   */
  public propfind(path: string, handler: RequestHandler) {
    this.router.addRoute('PROPFIND', path, handler);
  }

  /**
   * 注册OPTIONS路由
   * @param path 路由路径
   * @param handler 处理函数
   */
  public options(path: string, handler: RequestHandler) {
    this.router.addRoute('OPTIONS', path, handler);
  }

  /**
   * 注册HEAD路由
   * @param path 路由路径
   * @param handler 处理函数
   */
  public head(path: string, handler: RequestHandler) {
    this.router.addRoute('HEAD', path, handler);
  }

  /**
   * 注册PATCH路由
   * @param path 路由路径
   * @param handler 处理函数
   */
  public patch(path: string, handler: RequestHandler) {
    this.router.addRoute('PATCH', path, handler);
  }

  /**
   * 注册COPY路由（WebDAV）
   * @param path 路由路径
   * @param handler 处理函数
   */
  public copy(path: string, handler: RequestHandler) {
    this.router.addRoute('COPY', path, handler);
  }

  /**
   * 注册MOVE路由（WebDAV）
   * @param path 路由路径
   * @param handler 处理函数
   */
  public move(path: string, handler: RequestHandler) {
    this.router.addRoute('MOVE', path, handler);
  }

  /**
   * 注册MKCOL路由（WebDAV - 创建集合/目录）
   * @param path 路由路径
   * @param handler 处理函数
   */
  public mkcol(path: string, handler: RequestHandler) {
    this.router.addRoute('MKCOL', path, handler);
  }

  /**
   * 注册LOCK路由（WebDAV）
   * @param path 路由路径
   * @param handler 处理函数
   */
  public lock(path: string, handler: RequestHandler) {
    this.router.addRoute('LOCK', path, handler);
  }

  /**
   * 注册UNLOCK路由（WebDAV）
   * @param path 路由路径
   * @param handler 处理函数
   */
  public unlock(path: string, handler: RequestHandler) {
    this.router.addRoute('UNLOCK', path, handler);
  }

  /**
   * 启用自动请求体解析中间件
   */
  public auto() {
    this.use(BodyParser.auto());
  }

  /**
   * 启用JSON请求体解析中间件
   */
  public json() {
    this.use(BodyParser.json());
  }

  /**
   * 启用URL编码请求体解析中间件
   */
  public urlencoded() {
    this.use(BodyParser.urlencoded());
  }

  /**
   * 启用多部分表单解析中间件
   */
  public multipart() {
    this.use(BodyParser.multipart());
  }

  /**
   * 启用文本请求体解析中间件
   */
  public plain() {
    this.use(BodyParser.plain());
  }

  /**
   * 启用静态文件服务
   * @param directoryPath 静态文件目录路径
   * @param options 缓存选项
   */
  public serveStatic(directoryPath: string, options?: CacheOptions) {
    this.router.addRoute('GET', '*', StaticFiles.serve(directoryPath, options));
  }

  /**
   * 启用CORS跨域支持
   * @param options CORS配置选项
   */
  public cors(options?: CorsOptions) {
    this.use(Cors.create(options));
  }

  /**
   * 启用日志中间件（开发环境格式）
   */
  public logger(options?: LoggerOptions) {
    this.use(Logger.create(options));
  }

  // ==================== 事件监听方法 ====================

  /**
   * 监听服务器错误事件
   * @param listener 错误事件监听器
   */
  public onError(listener: ErrorEventListener): void {
    this.eventEmitter.onError(listener);
  }

  /**
   * 监听服务器事件
   * @param eventType 事件类型
   * @param listener 事件监听器
   */
  public on(eventType: ServerEventType, listener: ServerEventListener): void {
    this.eventEmitter.on(eventType, listener);
  }

  /**
   * 移除错误监听器
   * @param listener 要移除的监听器
   */
  public removeErrorListener(listener: ErrorEventListener): void {
    this.eventEmitter.removeErrorListener(listener);
  }

  /**
   * 移除事件监听器
   * @param eventType 事件类型
   * @param listener 要移除的监听器
   */
  public removeListener(eventType: ServerEventType, listener: ServerEventListener): void {
    this.eventEmitter.removeListener(eventType, listener);
  }

  /**
   * 清除所有事件监听器
   */
  public removeAllListeners(): void {
    this.eventEmitter.removeAllListeners();
  }

  // ==================== 服务器状态查询方法 ====================

  /**
   * 获取服务器运行状态
   * @returns 运行状态
   */
  public async getState(): Promise<socket.SocketStateBase | undefined> {
    return await this.tcpServer?.getState()
  }

  /**
   * 获取当前连接的客户端数量
   * @returns 客户端数量
   */
  public getClientCount(): number {
    return this.clients.size;
  }

  /**
   * 获取所有客户端信息
   * @returns 客户端信息数组
   */
  public getClients(): (socket.TCPSocketConnection | socket.TLSSocketConnection)[] {
    return Array.from(this.clients.values());
  }

  /**
   * 根据ID获取客户端信息
   * @param clientId 客户端ID
   * @returns 客户端信息或undefined
   */
  public getClient(clientId: number): socket.TCPSocketConnection | socket.TLSSocketConnection | undefined {
    return this.clients.get(clientId);
  }

  /**
   * 断开指定客户端连接
   * @param clientId 客户端ID
   */
  public async disconnectClient(clientId: number): Promise<boolean> {
    const clientInfo = this.clients.get(clientId);
    if (clientInfo) {
      try {
        await clientInfo.close();
        return true;
      } catch (error) {
        this.eventEmitter.emitError(error, ServerErrorType.CLIENT_ERROR);
        return false;
      }
    }
    return false;
  }

  /**
   * 启动服务器
   * @param port 监听端口
   * @param address 地址
   * @returns 服务器信息
   */
  public async startServer(port: number, address: string = ''): Promise<socket.NetAddress> {
    try {
      this.tcpServer = socket.constructTCPSocketServerInstance();
      try {
        // 尝试监听端口
        await this.tcpServer.listen({
          address: address || this.getLocalIP(),
          port: port
        });
      } catch (listenError) {
        this.eventEmitter.emitError(listenError, ServerErrorType.LISTEN_ERROR);
        return { address: '', port: 0 };
      }

      const info = await this.tcpServer.getLocalAddress()

      // 设置客户端连接监听
      this.tcpServer.on('connect', (clientSocket) => this.handleClient(clientSocket));
      // 设置服务器错误监听
      this.tcpServer.on('error', (error) => {
        this.eventEmitter.emitError(error, ServerErrorType.SOCKET_ERROR);
      });

      // 发射服务器启动事件
      const startEvent: ServerEvent = {
        type: ServerEventType.SERVER_STARTED,
        data: info
      };
      this.eventEmitter.emit(startEvent);
      return info
    } catch (error) {
      this.eventEmitter.emitError(new Error('服务器启动失败'), ServerErrorType.STARTUP_FAILED);
      return { address: '', port: 0 };
    }
  }

  /**
   * 停止服务器
   */
  public async stopServer(): Promise<void> {
    if (this.tcpServer) {
      try {
        this.clients.forEach(async (client, _) => {
          client.close();
        })
        this.clients.clear();
        this.tcpServer.off('connect');
        this.tcpServer.off('error');

        if (deviceInfo.sdkApiVersion >= 20) {
          await this.tcpServer.close()
        }
        this.tcpServer = null;
        this.eventEmitter.emit({ type: ServerEventType.SERVER_STOPPED });
      } catch (error) {
        this.tcpServer = null;
        this.eventEmitter.emitError(error, ServerErrorType.UNKNOWN_ERROR);
      }
    }
  }

  /**
   * 检查HTTP请求是否完整
   * @param buffer 缓冲区数据
   * @returns 是否为完整请求
   */
  protected isRequestComplete(buffer: ArrayBuffer): boolean {
    const bufferStr = Utils.arrayBufferToStr(buffer);
    const headerEndIndex = bufferStr.indexOf('\r\n\r\n');

    if (headerEndIndex === -1) {
      return false; // 头部不完整
    }

    const headerStr = bufferStr.substring(0, headerEndIndex);
    
    // 检查是否使用分块传输编码
    const transferEncodingMatch = headerStr.match(/Transfer-Encoding:\s*chunked/i);
    if (transferEncodingMatch) {
      // 分块传输：检查是否收到结束标记 "0\r\n\r\n"
      return bufferStr.endsWith('0\r\n\r\n');
    }

    // 解析Content-Length
    const contentLengthMatch = headerStr.match(/Content-Length:\s*(\d+)/i);
    const contentLength = contentLengthMatch ? parseInt(contentLengthMatch[1]) : 0;

    // 计算完整请求的总长度
    const headerLength = headerEndIndex + 4; // 包括 \r\n\r\n
    const totalRequestLength = headerLength + contentLength;

    return buffer.byteLength >= totalRequestLength;
  }

  /**
   * 移除客户端连接
   * @param clientSocket 客户端Socket连接
   * @param error 错误信息（可选）
   */
  protected removeClient(clientSocket: socket.TCPSocketConnection | socket.TLSSocketConnection, error?: BusinessError) {
    this.clients.delete(clientSocket.clientId);
    if (error) {
      this.eventEmitter.emitError(error, ServerErrorType.CLIENT_ERROR);
    }
  }


  /**
   * 处理客户端连接
   * @param clientSocket 客户端Socket连接
   */
  protected handleClient(clientSocket: socket.TCPSocketConnection | socket.TLSSocketConnection) {
    this.clients.set(clientSocket.clientId, clientSocket);

    // 初始化客户端上下文
    const ctx: ClientContext = {
      state: ClientState.WAITING_HEADER,
      buffer: new ArrayBuffer(0),
      req: null,
      res: null,
      contentLength: 0,
      receivedBodyLength: 0,
      isChunked: false
    };

    clientSocket.on('message', async (data) => {
      console.log('SOCKET_MSG: ' + util.TextDecoder.create().decodeToString(new Uint8Array(data.message)))
      try {
        // 第一时间将新数据追加到统一缓冲区
        ctx.buffer = Utils.mergeArrayBuffers(ctx.buffer, data.message);

        // 使用 while 循环处理缓冲区中的所有完整请求
        while (ctx.buffer.byteLength > 0) {
          if (ctx.state === ClientState.WAITING_HEADER) {
            // 状态：等待Header
            // 查找 Header 结束位置（\r\n\r\n）
            const headerEndIndex = this.findHeaderEnd(ctx.buffer);
            if (headerEndIndex === -1) {
              // Header 不完整，跳出循环等待更多数据
              break;
            }

            // Header 已完整，提取并解析
            const headerData = ctx.buffer.slice(0, headerEndIndex);
            const headerStr = Utils.arrayBufferToStr(headerData);

            // 解析 Content-Length 和 Transfer-Encoding
            const contentLengthMatch = headerStr.match(/Content-Length:\s*(\d+)/i);
            const transferEncodingMatch = headerStr.match(/Transfer-Encoding:\s*chunked/i);

            ctx.contentLength = contentLengthMatch ? parseInt(contentLengthMatch[1]) : 0;
            ctx.isChunked = transferEncodingMatch !== null;

            // 关键点：从主缓冲区切除已解析的 Header，严格保留剩余数据
            ctx.buffer = ctx.buffer.slice(headerEndIndex);

            // 创建 HttpRequest 和 HttpResponse
            const socketData: socket.SocketMessageInfo = {
              message: headerData,
              remoteInfo: data.remoteInfo
            };

            ctx.req = new HttpRequest(socketData);
            ctx.res = new HttpResponse(clientSocket);

            // 发射请求接收事件
            this.eventEmitter.emit({
              type: ServerEventType.REQUEST_RECEIVED,
              data: { clientSocket, data: socketData }
            });

            // 添加响应完成回调
            ctx.res.onFinish((statusCode, responseSize) => {
              this.eventEmitter.emit({
                type: ServerEventType.RESPONSE_SENT,
                data: { clientSocket, statusCode, responseSize }
              });
            });

            // 立即调用路由处理器（不等待Body）
            this.router.handle(ctx.req, ctx.res);

            // 关键点：判断是否有 Body
            const hasBody = ctx.contentLength > 0 || ctx.isChunked;
            if (!hasBody) {
              // 无 Body 请求（如 GET、OPTIONS），直接触发 end 并重置状态
              ctx.req.emitEnd();
              this.resetClientContext(ctx);
              // continue 继续循环解析下一个请求
              continue;
            }

            // 有 Body，切换到 STREAMING_BODY 状态
            ctx.state = ClientState.STREAMING_BODY;
            ctx.receivedBodyLength = 0;
            // continue 继续处理可能已经在 buffer 中的 Body 数据
            continue;

          } else if (ctx.state === ClientState.STREAMING_BODY) {
            // 状态：流式接收 Body
            if (!ctx.req) {
              // 异常情况，重置状态
              this.resetClientContext(ctx);
              break;
            }

            if (ctx.isChunked) {
              // 分块传输模式
              const GeneratedDestructObj_1 = this.parseChunkedDataWithContext(ctx.buffer);
              const chunks = GeneratedDestructObj_1.chunks;
              const remaining = GeneratedDestructObj_1.remaining;
              const isComplete = GeneratedDestructObj_1.isComplete;

              // 分发解析出的数据块
              for (const chunk of chunks) {
                ctx.receivedBodyLength += chunk.byteLength;
                ctx.req.emitData(chunk);
              }

              // 关键点：更新 buffer 剔除已读数据
              ctx.buffer = remaining;

              // 检查是否接收完毕
              if (isComplete) {
                ctx.req.emitEnd();
                this.resetClientContext(ctx);
                // continue 继续处理可能存在的下一个请求
                continue;
              }

              // Body 未完整，跳出循环等待更多数据
              break;

            } else {
              // Content-Length 模式
              const neededLength = ctx.contentLength - ctx.receivedBodyLength;
              const availableLength = ctx.buffer.byteLength;

              if (availableLength >= neededLength) {
                // 已有足够的数据
                const bodyData = ctx.buffer.slice(0, neededLength);
                ctx.receivedBodyLength += bodyData.byteLength;
                ctx.req.emitData(bodyData);

                // 关键点：更新 buffer 剔除已读数据
                ctx.buffer = ctx.buffer.slice(neededLength);

                // Body 接收完毕
                ctx.req.emitEnd();
                this.resetClientContext(ctx);
                // continue 继续处理可能存在的下一个请求
                continue;

              } else {
                // 数据不足，全部取出并等待更多
                if (availableLength > 0) {
                  ctx.receivedBodyLength += availableLength;
                  ctx.req.emitData(ctx.buffer);
                  ctx.buffer = new ArrayBuffer(0);
                }
                // 跳出循环等待更多数据
                break;
              }
            }
          }
        }
      } catch (error) {
        this.eventEmitter.emitError(error, ServerErrorType.CLIENT_ERROR);
      }
    });

    clientSocket.on('error', (err) => {
      // 清理资源
      if (ctx.req) {
        ctx.req.emitError(err);
      }
      this.removeClient(clientSocket, err);
    });

    clientSocket.on('close', () => {
      // 清理资源
      if (ctx.req) {
        ctx.req.emitEnd();
      }
      this.removeClient(clientSocket);
    });
  }

  /**
   * 查找Header结束位置
   * @param buffer 缓冲区数据
   * @returns Header结束位置（包含\r\n\r\n），-1表示未找到
   */
  private findHeaderEnd(buffer: ArrayBuffer): number {
    const bufferStr = Utils.arrayBufferToStr(buffer);
    const headerEndIndex = bufferStr.indexOf('\r\n\r\n');
    return headerEndIndex !== -1 ? headerEndIndex + 4 : -1;
  }

  /**
   * 解析分块传输数据（带完成状态）
   * @param buffer 缓冲区数据
   * @returns 解析出的数据块、剩余数据和是否完成标志
   */
  private parseChunkedDataWithContext(buffer: ArrayBuffer): HttpServerChunkedData {
    const chunks: ArrayBuffer[] = [];
    const bufferStr = Utils.arrayBufferToStr(buffer);
    let offset = 0;
    let lastChunkEnd = 0;
    let isComplete = false;

    while (offset < bufferStr.length) {
      const crlfIndex = bufferStr.indexOf('\r\n', offset);
      if (crlfIndex === -1) {
        break;
      }

      const chunkSizeStr = bufferStr.substring(offset, crlfIndex);
      const chunkSize = parseInt(chunkSizeStr, 16);

      if (isNaN(chunkSize)) {
        break;
      }

      if (chunkSize === 0) {
        // 结束块，检查是否有完整的结束标记 \r\n
        const endMarkerStart = crlfIndex + 2;
        if (bufferStr.length >= endMarkerStart + 2 && bufferStr.substring(endMarkerStart, endMarkerStart + 2) === '\r\n') {
          lastChunkEnd = endMarkerStart + 2;
          isComplete = true;
        } else {
          // 结束标记不完整，等待更多数据
          lastChunkEnd = offset;
        }
        break;
      }

      const chunkStart = crlfIndex + 2;
      const chunkEnd = chunkStart + chunkSize;

      if (chunkEnd + 2 > bufferStr.length) {
        // 数据不完整，等待更多数据
        break;
      }

      const chunkData = buffer.slice(chunkStart, chunkEnd);
      chunks.push(chunkData);

      offset = chunkEnd + 2;
      lastChunkEnd = offset;
    }

    const remaining = buffer.slice(lastChunkEnd);
    return { chunks, remaining, isComplete };
  }

  /**
   * 解析分块传输数据
   * @param buffer 缓冲区数据
   * @returns 解析出的数据块和剩余数据
   */
  private parseChunkedData(buffer: ArrayBuffer): HttpChunkedData {
    const chunks: ArrayBuffer[] = [];
    const bufferStr = Utils.arrayBufferToStr(buffer);
    let offset = 0;
    let lastChunkEnd = 0;

    while (offset < bufferStr.length) {
      const crlfIndex = bufferStr.indexOf('\r\n', offset);
      if (crlfIndex === -1) {
        break;
      }

      const chunkSizeStr = bufferStr.substring(offset, crlfIndex);
      const chunkSize = parseInt(chunkSizeStr, 16);

      if (isNaN(chunkSize)) {
        break;
      }

      if (chunkSize === 0) {
        // 结束块
        lastChunkEnd = crlfIndex + 2;
        break;
      }

      const chunkStart = crlfIndex + 2;
      const chunkEnd = chunkStart + chunkSize;

      if (chunkEnd + 2 > bufferStr.length) {
        // 数据不完整，等待更多数据
        break;
      }

      const chunkData = buffer.slice(chunkStart, chunkEnd);
      chunks.push(chunkData);

      offset = chunkEnd + 2;
      lastChunkEnd = offset;
    }

    const remaining = buffer.slice(lastChunkEnd);
    return { chunks, remaining };
  }

  /**
   * 检查分块传输是否完成
   * @param buffer 缓冲区数据
   * @returns 是否完成
   */
  private isChunkedComplete(buffer: ArrayBuffer): boolean {
    const bufferStr = Utils.arrayBufferToStr(buffer);
    return bufferStr.includes('0\r\n\r\n');
  }

  /**
   * 重置客户端上下文
   * 注意：该方法仅重置请求相关状态，绝对禁止操作 ctx.buffer
   * @param ctx 客户端上下文
   */
  private resetClientContext(ctx: ClientContext): void {
    ctx.state = ClientState.WAITING_HEADER;
    ctx.req = null;
    ctx.res = null;
    ctx.contentLength = 0;
    ctx.receivedBodyLength = 0;
    ctx.isChunked = false;
    // 注意：不操作 ctx.buffer，保留剩余数据用于下一个请求
  }

  /**
   * 获取本地IP地址
   * @returns IP地址字符串
   */
  protected getLocalIP(): string {
    const localIP = '127-0-0-1'.replaceAll('-', '.')
    // 模拟器直接返回固定的
    if (deviceInfo.productModel === 'emulator') {
      return localIP;
    }

    try {
      const netHandle = connection.getDefaultNetSync();
      if (netHandle.netId === 0) {
        // 当前没有已连接的网络时，获取的netHandler的netid为0
        return localIP;
      }
      const connectionproperties = connection.getConnectionPropertiesSync(netHandle);
      return connectionproperties.linkAddresses[0].address.address;
    } catch (e) {
      return localIP;
    }
  }
}