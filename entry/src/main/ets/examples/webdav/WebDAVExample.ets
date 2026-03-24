/**
 * @fileName : WebDAVExample.ets
 * @author : @cxy
 * @date : 2025/3/24
 * @description : WebDAV服务器示例 - 展示如何使用WebDAVServer
 */

import { WebDAVServer } from '@cxy/webserver/webdav/WebDAVServer';
import { socket } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';

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
 * // 3. 客户端访问
 * // Windows: 映射网络驱动器 -> http://192.168.1.100:8080/photos
 * // macOS: Finder -> 连接服务器 -> http://192.168.1.100:8080/photos
 * // Linux: davfs2 mount http://192.168.1.100:8080/photos /mnt/photos
 */
