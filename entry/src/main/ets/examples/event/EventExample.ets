/**
 * @fileName : EventExample.ets
 * @author : @cxy
 * @date : 2025/10/29
 * @description : Event示例 - 展示服务器事件系统功能
 */

import {
  HttpServer, ServerEventType, ServerErrorType, HttpRequest, HttpResponse,
} from '@handwer/webdav-server';
import { socket } from '@kit.NetworkKit';


/**
 * Event示例类
 * 展示服务器事件系统的各种功能
 */
export class EventExample {
  private server: HttpServer | null = null;

  /**
   * 初始化服务器
   */
  public initializeServer(): void {
    this.server = new HttpServer();
    this.setupEventHandling();
    this.setupMiddleware();
    this.setupRoutes()
  }

  /**
   * 启动服务器
   */
  public async start(port: number): Promise<socket.NetAddress | null> {
    if (!this.server) {
      this.initializeServer();
    }

    const info = await this.server?.startServer(port);
    if (info) {
      console.log('✅ 服务器启动成功!');
      console.log(`🌐 访问地址: http://${info.address}:${info.port}`);
      this.printApiEndpoints(info);
      return info;
    } else {
      console.error('❌ 启动服务器失败:');
      return null
    }
  }

  /**
   * 停止服务器
   */
  public async stop(): Promise<void> {
    if (this.server) {
      await this.server.stopServer();
    }
  }

  /**
   * 配置测试路由
   */
  private setupRoutes(): void {
    const server = this.server
    if (!server) {
      return
    }

    // 首页
    server.get('/', (req: HttpRequest, res: HttpResponse) => {
      res.json({
        message: 'HTTP服务器运行正常',
        timestamp: new Date().toISOString(),
        clientCount: server.getClientCount()
      });
    });

    // 服务器状态端点
    server.get('/status', async (req: HttpRequest, res: HttpResponse) => {
      const clients = server.getClients().map(client => client.clientId);

      res.json({
        status: 'running',
        clientCount: server.getClientCount(),
        clients: clients,
        timestamp: new Date().toISOString()
      });
    });

    // 模拟错误的端点
    server.get('/error', (req: HttpRequest, res: HttpResponse) => {
      // 故意抛出错误来测试错误处理
      throw new Error('这是一个测试错误');
    });

    // 断开指定客户端连接
    server.post('/disconnect/:clientId', async (req: HttpRequest, res: HttpResponse) => {
      const clientId = Number(req.params['clientId']);
      const success = await server.disconnectClient(clientId);

      res.json({
        success,
        message: success ? `客户端 ${clientId} 已断开连接` : `客户端 ${clientId} 不存在或断开失败`
      });
    });
  }

  /**
   * 设置事件处理
   */
  private setupEventHandling(): void {
    if (!this.server) {
      return;
    }

    // 监听服务器错误事件
    this.server.onError((error) => {
      console.error(`服务器错误 [${error.type}]:`, JSON.stringify(error.error));

      // 根据错误类型进行不同处理
      switch (error.type) {
        case ServerErrorType.STARTUP_FAILED:
          console.error('服务器启动失败，请检查端口是否被占用');
          // 可以在这里实现重试逻辑或通知管理员
          break;

        case ServerErrorType.LISTEN_ERROR:
          console.error('端口监听失败，可能端口已被占用');
          // 可以尝试其他端口
          break;

        case ServerErrorType.CONNECTION_ERROR:
          console.error('连接错误，客户端连接异常');
          break;

        case ServerErrorType.CLIENT_ERROR:
          console.error('客户端错误');
          break;

        case ServerErrorType.SOCKET_ERROR:
          console.error('Socket错误');
          break;

        default:
          console.error('未知错误类型');
      }
    });

    // 监听服务器事件
    Object.values(ServerEventType).forEach(eventType => {
      this.server!.on(eventType, (event) => {
        console.log(`📡 服务器事件 [${eventType}]: ${JSON.stringify(event.data)}`);
      });
    });

  }

  /**
   * 配置中间件
   */
  private setupMiddleware(): void {
    if (!this.server) {
      return;
    }

    this.server.logger();
    this.server.cors();
    this.server.auto();
  }

  /**
   * 打印API端点信息
   */
  private printApiEndpoints(info: socket.NetAddress): void {
    const baseUrl = `http://${info.address}:${info.port}`;

    console.log('\n📡 Event API端点:');
    console.log('='.repeat(50));
    console.log(`   GET ${baseUrl}/        (返回服务器状态和客户端数量)`);
    console.log(`   GET ${baseUrl}/status  (返回服务器运行状态和客户端信息)`);
    console.log(`   GET ${baseUrl}/error   (故意触发错误以测试错误处理)`);
    console.log(`   POST ${baseUrl}/disconnect/:clientId (断开指定客户端连接)`);
    console.log('='.repeat(50));
  }
}