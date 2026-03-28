/**
 * @fileName : WebDAVExample.ets
 * @author : @cxy
 * @date : 2025/3/24
 * @description : WebDAV服务器示例 - 展示如何使用WebDAVServer
 */

import { socket } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';
import { WebDAVServer } from '@handwer/webdav-server';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

/**
 * WebDAV示例类
 */
export class WebDAVExample {
  private dav: WebDAVServer | null = null;
  private context?: common.UIAbilityContext;

  /**
   * 初始化
   */
  init(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * 启动WebDAV服务器（简单示例）
   */
  public async startSimple(): Promise<socket.NetAddress | null> {
    // 创建WebDAV服务器
    this.dav = new WebDAVServer({
      port: 8080,
      enableLogging: true
    });
    try {
      fileIo.mkdirSync(`${this.context?.filesDir}/albums`)
      fileIo.mkdirSync(`${this.context?.filesDir}/docs`)
      fileIo.mkdirSync(`${this.context?.filesDir}/music`)
    } catch {}

    // 挂载目录
    this.dav.mount('/photos', `${this.context?.filesDir}/albums`);
    this.dav.mount('/documents', `${this.context?.filesDir}/docs`);
    this.dav.mount('/music', `${this.context?.filesDir}/music`);

    // 启动服务器
    return await this.dav.start();
  }

  /**
   * 启动WebDAV服务器（完整配置示例）
   */
  public async startAdvanced(): Promise<socket.NetAddress | null> {
    // 创建WebDAV服务器（带身份验证）
    this.dav = new WebDAVServer({
      port: 8443,
      enableAuth: true,
      username: 'admin',
      password: 'password123',
      enableLogging: true
    });

    // 挂载多个目录
    this.dav.mount('/public', `${this.context?.filesDir}/public`);
    this.dav.mount('/private', `${this.context?.filesDir}/private`);
    this.dav.mount('/backup', `${this.context?.cacheDir}/backup`);

    // 启动服务器
    return await this.dav.start();
  }

  /**
   * 启动WebDAV服务器（带日志重定向示例）
   * 演示如何将日志重定向到文件或自定义处理函数
   */
  public async startWithLogRedirect(): Promise<socket.NetAddress | null> {
    // 方式1: 在构造函数中配置日志流
    const logFilePath = `${this.context?.filesDir}/webdav.log`;
    
    this.dav = new WebDAVServer({
      port: 8080,
      enableLogging: true,
      logFormat: 'combined',  // 使用Apache combined格式
      // 配置日志输出到文件
      logStream: (message: string) => {
        // 异步写入日志文件
        this.writeLogToFile(logFilePath, message);
        // 同时输出到控制台
        console.log(`[WebDAV Log] ${message.trim()}`);
      }
    });

    // 方式2: 使用setLogStream方法动态设置日志流
    // this.dav = new WebDAVServer({ port: 8080, enableLogging: true });
    // this.dav.setLogStream((message: string) => {
    //   this.writeLogToFile(logFilePath, message);
    // });

    // 挂载目录
    this.dav.mount('/photos', `${this.context?.filesDir}/albums`);
    this.dav.mount('/documents', `${this.context?.filesDir}/docs`);

    // 启动服务器
    return await this.dav.start();
  }

  /**
   * 将日志写入文件
   * @param filePath 日志文件路径
   * @param message 日志消息
   */
  private async writeLogToFile(filePath: string, message: string): Promise<void> {
    try {
      const file = await fileIo.open(filePath, 
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.APPEND);
      const encoder = new util.TextEncoder();
      await fileIo.write(file.fd, encoder.encodeInto(message).buffer);
      await fileIo.close(file.fd);
    } catch (error) {
      console.error('[WebDAV] 写入日志文件失败:', error);
    }
  }

  /**
   * 停止服务器
   */
  public async stop(): Promise<void> {
    if (this.dav) {
      await this.dav.stop();
      this.dav = null;
    }
  }
}

/**
 * 使用示例：
 * 
 * // 1. 简单使用（三行代码启动服务）
 * const dav = new WebDAVServer({ port: 8080 });
 * dav.mount('/photos', context.filesDir + '/albums');
 * dav.start();
 * 
 * // 2. 完整配置
 * const dav = new WebDAVServer({
 *   port: 8080,
 *   enableAuth: true,
 *   username: 'admin',
 *   password: 'password',
 *   enableLogging: true
 * });
 * 
 * dav.mount('/photos', context.filesDir + '/albums');
 * dav.mount('/documents', context.filesDir + '/docs');
 * dav.mount('/music', context.filesDir + '/music');
 * 
 * await dav.start();
 * 
 * // 3. 日志重定向到文件
 * const dav = new WebDAVServer({
 *   port: 8080,
 *   enableLogging: true,
 *   logFormat: 'combined',  // 使用Apache combined格式
 *   logStream: (message: string) => {
 *     // 写入日志文件
 *     writeToFile('/path/to/webdav.log', message);
 *     // 同时输出到控制台
 *     console.log(message);
 *   }
 * });
 * 
 * // 4. 动态设置日志流
 * const dav = new WebDAVServer({ port: 8080, enableLogging: true });
 * dav.setLogStream((message: string) => {
 *   // 自定义日志处理
 *   sendToRemoteServer(message);
 * });
 * 
 * // 5. 客户端访问
 * // Windows: 映射网络驱动器 -> http://192.168.1.100:8080/photos
 * // macOS: Finder -> 连接服务器 -> http://192.168.1.100:8080/photos
 * // Linux: davfs2 mount http://192.168.1.100:8080/photos /mnt/photos
 */
