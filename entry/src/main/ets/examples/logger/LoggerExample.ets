/**
 * @fileName : LoggerExample.ets
 * @author : @cxy
 * @date : 2025/10/29
 * @description : Logger示例 - 展示日志记录功能
 */

import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import {
  HttpServer,
  ErrorHandler,
  ServerEventType,
  HttpRequest,
  HttpResponse,
  NextFunction,
} from '@handwer/webdav-server';
import { util } from '@kit.ArkTS';
import { socket } from '@kit.NetworkKit';


/**
 * 日志记录接口
 */
interface LogRecord {
  id: number;
  timestamp: Date;
  level: 'debug' | 'info' | 'warn' | 'error';
  method: string;
  url: string;
  statusCode: number;
  responseTime: number;
  userAgent: string;
  ip: string;
  message: string;
}

interface LogStat {
  byLevel: Record<string, number>,
  byMethod: Record<string, number>,
  byStatusCode: Record<string, number>,
  averageResponseTime: number,
  errorRate: number
}

/**
 * Logger示例类
 * 展示各种日志记录功能和格式
 */
export class LoggerExample {
  public logFormat: 'dev' | 'combined' | 'common' | 'short' | 'tiny' = 'dev';
  public logLevel: 'debug' | 'info' | 'warn' | 'error' = 'debug';
  // 日志记录
  public logRecords: LogRecord[] = [];
  private server: HttpServer | null = null;
  private nextLogId: number = 1;
  private logFilePath: string = ''

  init(context: common.UIAbilityContext) {
    this.logFilePath = context.filesDir + '/server.log';
  }


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

  /**
   * 设置事件处理
   */
  private setupEventHandling(): void {
    if (!this.server) {
      return;
    }

    this.server.onError((error) => {
      this.writeLog('error', `服务器错误: ${JSON.stringify(error)}`, {
        errorType: error.type
      });
    });

    this.server.on(ServerEventType.SERVER_STARTED, (event) => {
      this.writeLog('info', '服务器启动成功', event.data);
    });

    this.server.on(ServerEventType.SERVER_STOPPED, () => {
      this.writeLog('info', '服务器已停止');
    });
  }

  /**
   * 设置全局错误处理
   */
  private setupGlobalErrorHandler(): void {
    if (!this.server) {
      return;
    }

    const errorHandler: ErrorHandler = (error, req, res, next) => {
      this.writeLog('error', `全局错误处理: ${error.message}`, {
        path: req.path,
        method: req.method,
        error: error.message
      });

      if (res.isHeadersSent()) {
        return next(error);
      }

      res.status(500).json({
        error: 'Logger Server Error',
        message: error.message,
        timestamp: new Date().toISOString()
      });
    };

    this.server.use(errorHandler);
  }


  /**
   * 配置中间件
   */
  private setupMiddleware(): void {
    if (!this.server) {
      return;
    }

    this.server.cors();

    // 自定义日志中间件
    this.server.use((req: HttpRequest, res: HttpResponse, next: NextFunction) => {
      const startTime = Date.now();

      // 记录请求开始
      this.writeLog('debug', `请求开始: ${req.method} ${req.path}`, {
        method: req.method,
        url: req.path,
        userAgent: req.userAgent,
        ip: req.ip
      });

      // 监听响应完成
      res.onFinish((statusCode, responseSize) => {
        const responseTime = Date.now() - startTime;

        // 记录详细的请求日志
        const logRecord: LogRecord = {
          id: this.nextLogId++,
          timestamp: new Date(),
          level: statusCode >= 400 ? 'error' : statusCode >= 300 ? 'warn' : 'info',
          method: req.method,
          url: req.url,
          statusCode,
          responseTime,
          userAgent: req.userAgent,
          ip: req.ip,
          message: this.formatLogMessage(req, statusCode, responseTime, responseSize)
        };

        this.logRecords.push(logRecord);

        // 限制日志记录数量
        if (this.logRecords.length > 1000) {
          this.logRecords = this.logRecords.slice(-1000);
        }

        // 写入文件日志
        this.writeToFile(logRecord);
        console.log(`📝 ${logRecord.message}`);
      });

      next();
    });

    this.server.auto();
  }

  /**
   * 格式化日志消息
   */
  private formatLogMessage(req: HttpRequest, statusCode: number, responseTime: number, responseSize: number): string {
    const timestamp = new Date().toISOString();

    switch (this.logFormat) {
      case 'combined':
        return `${req.ip} - - [${timestamp}] "${req.method} ${req.url} HTTP/1.1" ${statusCode} ${responseSize} "${req.referer}" "${req.userAgent}"`;

      case 'common':
        return `${req.ip} - - [${timestamp}] "${req.method} ${req.url} HTTP/1.1" ${statusCode} ${responseSize}`;

      case 'short':
        return `${req.ip} ${req.method} ${req.url} HTTP/1.1 ${statusCode} ${responseSize} - ${responseTime}ms`;

      case 'tiny':
        return `${req.method} ${req.url} ${statusCode} ${responseSize} - ${responseTime}ms`;

      case 'dev':
      default:
        const statusColor = statusCode >= 400 ? '🔴' : statusCode >= 300 ? '🟡' : '🟢';
        return `${statusColor} ${req.method} ${req.url} ${statusCode} ${responseTime}ms - ${responseSize}b`;
    }
  }

  /**
   * 写入日志
   */
  private writeLog(level: 'debug' | 'info' | 'warn' | 'error', message: string, data?: ESObject): void {
    const logLevels = {
      'debug': 0,
      'info': 1,
      'warn': 2,
      'error': 3
    } as Record<string, number>
    const configLevel = logLevels[this.logLevel];
    const messageLevel = logLevels[level];

    if (messageLevel >= configLevel) {
      const timestamp = new Date().toISOString();
      const logMessage = `[${timestamp}] [${level.toUpperCase()}] ${message}`;

      if (data) {
        console.log(logMessage, data);
      } else {
        console.log(logMessage);
      }


      this.writeToFile({
        id: this.nextLogId++,
        timestamp: new Date(),
        level,
        method: '',
        url: '',
        statusCode: 0,
        responseTime: 0,
        userAgent: '',
        ip: '',
        message: logMessage
      });

    }
  }

  /**
   * 写入文件日志
   */
  private async writeToFile(logRecord: LogRecord): Promise<void> {
    try {
      const logLine = `${logRecord.message}\n`;
      const file = await fileIo.open(this.logFilePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.APPEND);
      await fileIo.write(file.fd, new util.TextEncoder().encodeInto(logLine).buffer);
      await fileIo.close(file.fd);
    } catch (error) {
      console.error('写入日志文件失败:', error);
    }
  }

  /**
   * 配置路由
   */
  private setupRoutes(): void {
    this.setupLogRoutes();
    this.setupTestRoutes();
  }

  /**
   * 日志查询路由
   */
  private setupLogRoutes(): void {
    if (!this.server) {
      return;
    }

    // 获取日志记录
    this.server.get('/api/logs', (req: HttpRequest, res: HttpResponse) => {
      const limit = parseInt(req.query.get('limit') || '50');
      const offset = parseInt(req.query.get('offset') || '0');
      const level = req.query.get('level');
      const method = req.query.get('method');

      let filteredLogs = this.logRecords;

      if (level) {
        filteredLogs = filteredLogs.filter(log => log.level === level);
      }

      if (method) {
        filteredLogs = filteredLogs.filter(log => log.method === method);
      }

      const logs = filteredLogs
        .slice(offset, offset + limit)
        .reverse();

      res.json({
        logs,
        total: filteredLogs.length,
        limit,
        offset,
        level,
        method
      });
    });

    // 获取日志统计
    this.server.get('/api/logs/stats', (req: HttpRequest, res: HttpResponse) => {
      const stats = this.analyzeLogStats();

      res.json({
        totalLogs: this.logRecords.length,
        byLevel: stats.byLevel,
        byMethod: stats.byMethod,
        byStatusCode: stats.byStatusCode,
        averageResponseTime: stats.averageResponseTime,
        errorRate: stats.errorRate
      });
    });

    // 清除日志记录
    this.server.delete('/api/logs', (req: HttpRequest, res: HttpResponse) => {
      const count = this.logRecords.length;
      this.logRecords = [];
      this.nextLogId = 1;

      res.json({
        message: 'Log records cleared',
        clearedCount: count
      });
    });
  }


  /**
   * 测试路由
   */
  private setupTestRoutes(): void {
    if (!this.server) {
      return;
    }

    // 测试不同级别的日志
    this.server.post('/api/logs/test/:level', (req: HttpRequest, res: HttpResponse) => {
      const level = req.params['level'] as 'debug' | 'info' | 'warn' | 'error';
      const message = `测试${level}级别日志`;

      this.writeLog(level, message, {
        testData: req.body,
        triggeredBy: 'api'
      });

      res.json({
        message: `${level} log generated`,
        logLevel: level,
        timestamp: new Date().toISOString()
      });
    });

    // 模拟慢请求
    this.server.get('/api/test/slow', (req: HttpRequest, res: HttpResponse) => {
      const delay = parseInt(req.query.get('delay') || '1000');

      setTimeout(() => {
        res.json({
          message: 'Slow request completed',
          delay,
          timestamp: new Date().toISOString()
        });
      }, delay);
    });

    // 模拟错误请求
    this.server.get('/api/test/error/:code', (req: HttpRequest, res: HttpResponse) => {
      const statusCode = parseInt(req.params['code']);

      res.status(statusCode).json({
        error: `Simulated ${statusCode} error`,
        timestamp: new Date().toISOString()
      });
    });
  }

  /**
   * 分析日志统计
   */
  private analyzeLogStats(): LogStat {
    const byLevel: Record<string, number> = {};
    const byMethod: Record<string, number> = {};
    const byStatusCode: Record<string, number> = {};
    let totalResponseTime = 0;
    let errorCount = 0;

    this.logRecords.forEach(log => {
      byLevel[log.level] = (byLevel[log.level] || 0) + 1;
      byMethod[log.method] = (byMethod[log.method] || 0) + 1;
      byStatusCode[log.statusCode] = (byStatusCode[log.statusCode] || 0) + 1;

      totalResponseTime += log.responseTime;

      if (log.statusCode >= 400) {
        errorCount++;
      }
    });

    return {
      byLevel,
      byMethod,
      byStatusCode,
      averageResponseTime: this.logRecords.length > 0 ? totalResponseTime / this.logRecords.length : 0,
      errorRate: this.logRecords.length > 0 ? (errorCount / this.logRecords.length) * 100 : 0
    }
  }


  /**
   * 打印API端点信息
   */
  private printApiEndpoints(info: socket.NetAddress): void {
    const baseUrl = `http://${info.address}:${info.port}`;

    console.log('\n📝 Logger API端点:');
    console.log('='.repeat(50));

    console.log('\n📊 日志查询:');
    console.log(`   GET    ${baseUrl}/api/logs             - 获取日志记录`);
    console.log(`   GET    ${baseUrl}/api/logs/stats       - 获取日志统计`);
    console.log(`   DELETE ${baseUrl}/api/logs             - 清除日志记录`);

    console.log('\n🧪 日志测试:');
    console.log(`   POST   ${baseUrl}/api/logs/test/:level - 测试日志级别`);
    console.log(`   GET    ${baseUrl}/api/test/slow        - 慢请求测试`);
    console.log(`   GET    ${baseUrl}/api/test/error/:code - 错误请求测试`);

    console.log('='.repeat(50));
  }
}