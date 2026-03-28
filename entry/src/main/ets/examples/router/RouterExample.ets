/**
 * @fileName : RouterExample.ets
 * @author : @cxy
 * @date : 2025/10/29
 * @description : Router示例 - 展示路由系统功能
 */

import {
  HttpServer,
  ErrorHandler,
  ServerEventType,
  HttpRequest,
  HttpResponse,
  NextFunction,
} from '@handwer/webdav-server';
import { socket } from '@kit.NetworkKit';

/**
 * 路由配置接口
 */
interface RouterConfig {
  port: number;
  staticRoot: string;
  enableLogging: boolean;
  enableCors: boolean;
}

/**
 * 路由记录接口
 */
interface RouteRecord {
  id: number;
  method: string;
  path: string;
  pattern: string;
  params: Record<string, string>;
  query: string;
  timestamp: Date;
  responseTime: number;
  statusCode: number;
}

/**
 * Router示例类
 * 展示路由系统的各种功能
 */
export class RouterExample {
  private server: HttpServer | null = null;
  // 路由记录
  private routeRecords: RouteRecord[] = [];
  private nextRouteId: number = 1;
  // 动态路由存储
  private dynamicRoutes: Map<string, Object> = new Map();

  /**
   * 初始化服务器
   */
  public initializeServer(): void {
    this.server = new HttpServer();

    this.setupEventHandling();
    this.setupMiddleware();
    this.setupRoutes();
    this.setupGlobalErrorHandler();
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
      return null;
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


  public getRouteCount(): number {
    return this.routeRecords.length;
  }


  /**
   * 设置事件处理
   */
  private setupEventHandling(): void {
    if (!this.server) {
      return;
    }

    this.server.onError((error) => {
      console.error(`🚨 Router服务器错误 [${error.type}]: ${JSON.stringify(error.error)}`);
    });

    this.server.on(ServerEventType.SERVER_STARTED, (event) => {
      console.log('✅ Router服务器启动成功:', event.data);
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

    // 路由记录中间件
    this.server.use((req: HttpRequest, res: HttpResponse, next: NextFunction) => {
      const startTime = Date.now();

      res.onFinish((statusCode) => {
        const responseTime = Date.now() - startTime;

        const routeRecord: RouteRecord = {
          id: this.nextRouteId++,
          method: req.method,
          path: req.path,
          pattern: req.url,
          params: req.params as Record<string, string>,
          query: JSON.stringify(req.query),
          timestamp: new Date(),
          responseTime,
          statusCode
        };

        this.routeRecords.push(routeRecord);

        // 限制记录数量
        if (this.routeRecords.length > 500) {
          this.routeRecords = this.routeRecords.slice(-500);
        }
      });

      next();
    });

    this.server.auto();
  }

  /**
   * 配置路由
   */
  private setupRoutes(): void {
    this.setupBasicRoutes();
    this.setupParameterRoutes();
    this.setupDynamicRoutes();
    this.setupRouteManagement();
  }

  /**
   * 基础路由
   */
  private setupBasicRoutes(): void {
    if (!this.server) {
      return;
    }

    // 根路径
    this.server.get('/', (req: HttpRequest, res: HttpResponse) => {
      res.json({
        message: 'Router示例首页',
        availableRoutes: [
          'GET /',
          'GET /about',
          'GET /contact',
          'GET /api/users/:id',
          'GET /api/products/:category/:id',
          'GET /files/*',
          'POST /api/routes'
        ],
        timestamp: new Date().toISOString()
      });
    });

    // 关于页面
    this.server.get('/about', (req: HttpRequest, res: HttpResponse) => {
      res.json({
        page: 'About',
        message: '这是关于页面',
        version: '1.0.1',
        features: ['基础路由', '路由参数', '路由管理']
      });
    });

    // 联系页面
    this.server.get('/contact', (req: HttpRequest, res: HttpResponse) => {
      res.json({
        page: 'Contact',
        message: '联系我们',
        github: 'https://github.com/iHongRen/WebServer'
      });
    });
  }

  /**
   * 参数路由
   */
  private setupParameterRoutes(): void {
    if (!this.server) {
      return;
    }

    // 单个参数
    this.server.get('/api/users/:id', (req: HttpRequest, res: HttpResponse) => {
      const userId = req.params['id'];

      res.json({
        route: '/api/users/:id',
        userId,
        name: `User ${userId}`,
        email: `user${userId}@example.com`,
        params: req.params,
        query: JSON.stringify(req.query),
      });
    });

    // 多个参数
    this.server.get('/api/products/:category/:id', (req: HttpRequest, res: HttpResponse) => {
      const data = req.params;

      res.json({
        route: '/api/products/:category/:id',
        category: data.category,
        productId: data.id,
        name: `Product ${data.id}`,
        price: Math.floor(Math.random() * 1000) + 100,
        params: req.params as Record<string, string>
      });
    });

    // 可选参数模拟
    this.server.get('/api/posts/:id', (req: HttpRequest, res: HttpResponse) => {
      const postId = req.params['id'];
      const format = req.query.get('format') || 'json';

      const post: Record<string, Object> = {
        'id': postId,
        'title': `Post ${postId}`,
        'content': `This is the content of post ${postId}`,
        'author': 'Admin',
        'createdAt': new Date().toISOString()
      };

      if (format === 'xml') {
        res.setHeader('Content-Type', 'application/xml');
        res.send(`<?xml version="1.0"?>
<post>
  <id>${post.id}</id>
  <title>${post.title}</title>
  <content>${post.content}</content>
  <author>${post.author}</author>
  <createdAt>${post.createdAt}</createdAt>
</post>`);
      } else {
        res.json(post);
      }
    });
  }

  /**
   * 动态路由管理
   */
  private setupDynamicRoutes(): void {
    if (!this.server) {
      return;
    }

    // 动态路由处理器
    this.server.use((req: HttpRequest, res: HttpResponse, next: NextFunction) => {
      const routeKey = `${req.method}:${req.path}`;
      const dynamicRoute = this.dynamicRoutes.get(routeKey);

      if (dynamicRoute) {
        res.json({
          message: '动态路由响应',
          route: req.path,
          method: req.method,
          config: dynamicRoute,
          timestamp: new Date().toISOString()
        });
      } else {
        next();
      }
    });
  }

  /**
   * 路由管理API
   */
  private setupRouteManagement(): void {
    if (!this.server) {
      return;
    }

    // 获取路由统计
    this.server.get('/api/routes/stats', (req: HttpRequest, res: HttpResponse) => {
      const stats = this.analyzeRouteStats() as Record<string, Object>;

      res.json({
        totalRequests: this.routeRecords.length,
        routeStats: stats.routeStats,
        methodStats: stats.methodStats,
        averageResponseTime: stats.averageResponseTime,
        popularRoutes: stats.popularRoutes,
        recentRequests: this.routeRecords.slice(-10).reverse()
      });
    });

    // 获取路由记录
    this.server.get('/api/routes/records', (req: HttpRequest, res: HttpResponse) => {
      const limit = parseInt(req.query.get('limit') || '50');
      const offset = parseInt(req.query.get('offset') || '0');
      const method = req.query.get('method');

      let filteredRecords = this.routeRecords;

      if (method) {
        filteredRecords = filteredRecords.filter(record => record.method === method);
      }

      const records = filteredRecords
        .slice(offset, offset + limit)
        .reverse();

      res.json({
        records,
        total: filteredRecords.length,
        limit,
        offset,
        method
      });
    });

    // 添加动态路由
    this.server.post('/api/routes', (req: HttpRequest, res: HttpResponse) => {
      const method = req.body.method as string
      const path = req.body.path as string
      const response = req.body.response as Object

      if (!method || !path) {
        res.status(400).json({
          error: 'Method and path are required'
        });
        return
      }

      const routeKey = `${method.toUpperCase()}:${path}`;
      this.dynamicRoutes.set(routeKey, {
        'method': method.toUpperCase(),
        'path': path,
        'response': response,
        'createdAt': new Date().toISOString()
      } as Record<string, Object>);

      res.json({
        message: 'Dynamic route added',
        routeKey,
        totalDynamicRoutes: this.dynamicRoutes.size
      });
    });

    // 删除动态路由
    this.server.delete('/api/routes/:method/:path', (req: HttpRequest, res: HttpResponse) => {
      const method = req.params.method
      const path = req.params.path

      const routeKey = `${method.toUpperCase()}:/${path}`;

      const deleted = this.dynamicRoutes.delete(routeKey);

      res.json({
        message: deleted ? 'Dynamic route deleted' : 'Route not found',
        routeKey,
        deleted,
        remainingRoutes: this.dynamicRoutes.size
      });
    });

    // 获取所有动态路由
    this.server.get('/api/routes/dynamic', (req: HttpRequest, res: HttpResponse) => {
      const routes = Array.from(this.dynamicRoutes)

      res.json({
        dynamicRoutes: routes,
        count: this.dynamicRoutes.size
      });
    });

    // 清除路由记录
    this.server.delete('/api/routes/records', (req: HttpRequest, res: HttpResponse) => {
      const count = this.routeRecords.length;
      this.routeRecords = [];
      this.nextRouteId = 1;

      res.json({
        message: 'Route records cleared',
        clearedCount: count
      });
    });
  }

  /**
   * 分析路由统计
   */
  private analyzeRouteStats() {
    const routeStats: Record<string, number> = {};
    const methodStats: Record<string, number> = {};
    let totalResponseTime = 0;

    this.routeRecords.forEach(record => {
      const routeKey = `${record.method} ${record.path}`;
      routeStats[routeKey] = (routeStats[routeKey] || 0) + 1;
      methodStats[record.method] = (methodStats[record.method] || 0) + 1;
      totalResponseTime += record.responseTime;
    });

    return {
      'routeStats': routeStats,
      'methodStats': methodStats,
      'averageResponseTime': this.routeRecords.length > 0 ? totalResponseTime / this.routeRecords.length : 0,
    } as Record<string, Object>
  }

  /**
   * 设置全局错误处理
   */
  private setupGlobalErrorHandler(): void {
    if (!this.server) {
      return;
    }

    const errorHandler: ErrorHandler = (error, req, res, next) => {
      console.error(`🚨 [Router Error Handler] ${req.method} ${req.path}: ${error.message}`);

      if (res.isHeadersSent()) {
        return next(error);
      }

      res.status(500).json({
        error: 'Router Server Error',
        message: error.message,
        route: req.path,
        method: req.method,
        timestamp: new Date().toISOString()
      });
    };

    this.server.use(errorHandler);
  }

  /**
   * 打印API端点信息
   */
  private printApiEndpoints(info: socket.NetAddress): void {
    const baseUrl = `http://${info.address}:${info.port}`;

    console.log('\n🛣️  Router API端点:');
    console.log('='.repeat(50));

    console.log('\n🏠 基础路由:');
    console.log(`   GET    ${baseUrl}/about               - 关于页面`);
    console.log(`   GET    ${baseUrl}/contact             - 联系页面`);

    console.log('\n🔗 参数路由:');
    console.log(`   GET    ${baseUrl}/api/users/:id       - 用户详情`);
    console.log(`   GET    ${baseUrl}/api/products/:category/:id - 产品详情`);
    console.log(`   GET    ${baseUrl}/api/posts/:id       - 文章详情`);

    console.log('\n⚙️ 路由管理:');
    console.log(`   GET    ${baseUrl}/api/routes/stats    - 路由统计`);
    console.log(`   GET    ${baseUrl}/api/routes/records  - 路由记录`);
    console.log(`   POST   ${baseUrl}/api/routes          - 添加动态路由`);
    console.log(`   GET    ${baseUrl}/api/routes/dynamic  - 获取动态路由`);
    console.log(`   DELETE ${baseUrl}/api/routes/records  - 清除路由记录`);

    console.log('='.repeat(50));
  }
}