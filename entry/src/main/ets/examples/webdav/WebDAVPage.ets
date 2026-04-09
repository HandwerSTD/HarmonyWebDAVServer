/**
 * @fileName : WebDAVPage.ets
 * @author : @cxy
 * @date : 2025/3/24
 * @description : WebDAV服务器示例页面
 */

import { common } from '@kit.AbilityKit';
import { WebDAVExample } from './WebDAVExample';
import { socket } from '@kit.NetworkKit';
import { http } from '@kit.NetworkKit';

/**
 * WebDAV页面构建器（用于路由注册）
 */
@Builder
function webdavBuilder() {
  WebDAVPage()
}

/**
 * WebDAV服务器示例页面
 */
@Entry
@Component
struct WebDAVPage {
  @State title: string = 'WebDAV服务器示例';
  @State serverStatus: string = '未启动';
  @State serverInfo: string = '';
  @State port: number = 8080;
  @State isRunning: boolean = false;
  @State mountPoints: string[] = [];
  @State testResult: string = '';
  @State isTesting: boolean = false;
  
  private context: common.UIAbilityContext | null = null;
  private webdavExample: WebDAVExample | null = null;
  private httpRequest: http.HttpRequest | null = null;

  /**
   * 页面即将显示
   */
  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    this.webdavExample = new WebDAVExample();
    this.webdavExample.init(this.context);
  }

  /**
   * 页面构建
   */
  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          // 服务器控制区域
          this.buildServerControl();
          
          // 功能说明
          this.buildFeatureDescription();
          
          // 挂载点信息
          this.buildMountPoints();
          
          // 客户端访问说明
          this.buildClientAccess();
          
          // 测试说明
          this.buildTestInstructions();
          
          // 测试按钮区域
          this.buildTestButtons();
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Auto)
    }
    .title(this.title)
    .onReady((ctx: NavDestinationContext) => {
      // 处理导航参数
    })
  }

  /**
   * 构建服务器控制区域
   */
  @Builder
  buildServerControl() {
    Column({ space: 12 }) {
      Text('服务器控制')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%');

      // 端口配置
      Row({ space: 8 }) {
        Text('端口:')
          .fontSize(14);
        
        TextInput({ text: this.port.toString() })
          .type(InputType.Number)
          .width(100)
          .height(40)
          .onChange((value: string) => {
            this.port = parseInt(value) || 8080;
          });
        
        Blank();
        
        // 启动/停止按钮
        Button(this.isRunning ? '停止服务器' : '启动服务器')
          .width(120)
          .height(40)
          .backgroundColor(this.isRunning ? '#FF5722' : '#4CAF50')
          .onClick(() => {
            if (this.isRunning) {
              this.stopServer();
            } else {
              this.startServer();
            }
          });
      }
      .width('100%');

      // 服务器状态
      Row({ space: 8 }) {
        Text('状态:')
          .fontSize(14);
        
        Text(this.serverStatus)
          .fontSize(14)
          .fontColor(this.isRunning ? '#4CAF50' : '#9E9E9E');
      }
      .width('100%');

      // 服务器信息
      if (this.serverInfo) {
        Text(this.serverInfo)
          .fontSize(12)
          .fontColor('#666666')
          .width('100%');
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F5F5F5')
    .borderRadius(8);
  }

  /**
   * 构建功能说明
   */
  @Builder
  buildFeatureDescription() {
    Column({ space: 12 }) {
      Text('功能说明')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%');

      this.featureItem('📁', '文件管理', '支持文件的创建、读取、更新、删除操作');
      this.featureItem('📂', '目录操作', '支持目录的创建、列表、删除操作');
      this.featureItem('🔄', '文件传输', '支持大文件的流式上传和下载');
      this.featureItem('🔒', '安全控制', '路径映射和访问权限控制');
      this.featureItem('🌐', '跨平台访问', '支持 Windows、macOS、Linux 客户端');
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8);
  }

  /**
   * 构建挂载点信息
   */
  @Builder
  buildMountPoints() {
    Column({ space: 12 }) {
      Text('挂载点')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%');

      if (this.mountPoints.length > 0) {
        ForEach(this.mountPoints, (point: string) => {
          Row({ space: 8 }) {
            Text('📂')
              .fontSize(16);
            
            Text(point)
              .fontSize(14)
              .layoutWeight(1);
          }
          .width('100%')
          .padding(8)
          .backgroundColor('#F5F5F5')
          .borderRadius(4);
        });
      } else {
        Text('暂无挂载点')
          .fontSize(14)
          .fontColor('#9E9E9E');
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8);
  }

  /**
   * 构建客户端访问说明
   */
  @Builder
  buildClientAccess() {
    Column({ space: 12 }) {
      Text('客户端访问')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%');

      // Windows
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text('🪟')
            .fontSize(16);
          
          Text('Windows')
            .fontSize(14)
            .fontWeight(FontWeight.Bold);
        }
        .width('100%');

        Text('1. 打开"此电脑"')
          .fontSize(12)
          .width('100%');
        
        Text('2. 点击"映射网络驱动器"')
          .fontSize(12)
          .width('100%');
        
        Text('3. 输入地址: http://<IP>:8080/photos')
          .fontSize(12)
          .width('100%');
      }
      .width('100%')
      .padding(8)
      .backgroundColor('#F5F5F5')
      .borderRadius(4);

      // macOS
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text('🍎')
            .fontSize(16);
          
          Text('macOS')
            .fontSize(14)
            .fontWeight(FontWeight.Bold);
        }
        .width('100%');

        Text('1. 打开 Finder')
          .fontSize(12)
          .width('100%');
        
        Text('2. 按 Cmd+K 或选择"连接服务器"')
          .fontSize(12)
          .width('100%');
        
        Text('3. 输入地址: http://<IP>:8080/photos')
          .fontSize(12)
          .width('100%');
      }
      .width('100%')
      .padding(8)
      .backgroundColor('#F5F5F5')
      .borderRadius(4);

      // Linux
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text('🐧')
            .fontSize(16);
          
          Text('Linux')
            .fontSize(14)
            .fontWeight(FontWeight.Bold);
        }
        .width('100%');

        Text('sudo apt-get install davfs2')
          .fontSize(12)
          .width('100%')
          .fontColor('#2196F3');
        
        Text('sudo mount -t davfs http://<IP>:8080/photos /mnt/photos')
          .fontSize(12)
          .width('100%')
          .fontColor('#2196F3');
      }
      .width('100%')
      .padding(8)
      .backgroundColor('#F5F5F5')
      .borderRadius(4);
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8);
  }

  /**
   * 构建测试说明
   */
  @Builder
  buildTestInstructions() {
    Column({ space: 12 }) {
      Text('测试说明')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%');

      Text('支持的 WebDAV 方法:')
        .fontSize(14)
        .width('100%');

      Row({ space: 8 }) {
        this.methodBadge('OPTIONS');
        this.methodBadge('PROPFIND');
        this.methodBadge('GET');
        this.methodBadge('PUT');
        this.methodBadge('DELETE');
      }
      .width('100%');

      Row({ space: 8 }) {
        this.methodBadge('MKCOL');
        this.methodBadge('MOVE');
        this.methodBadge('COPY');
        this.methodBadge('HEAD');
      }
      .width('100%');

      // curl 测试示例
      Column({ space: 8 }) {
        Text('curl 测试命令:')
          .fontSize(14)
          .width('100%');

        Text('# 列出目录内容')
          .fontSize(12)
          .width('100%')
          .fontColor('#666666');
        
        Text('curl -X PROPFIND http://localhost:8080/photos')
          .fontSize(12)
          .width('100%')
          .fontColor('#2196F3');

        Text('# 上传文件')
          .fontSize(12)
          .width('100%')
          .fontColor('#666666');
        
        Text('curl -T file.txt http://localhost:8080/photos/file.txt')
          .fontSize(12)
          .width('100%')
          .fontColor('#2196F3');

        Text('# 下载文件')
          .fontSize(12)
          .width('100%')
          .fontColor('#666666');
        
        Text('curl -O http://localhost:8080/photos/file.txt')
          .fontSize(12)
          .width('100%')
          .fontColor('#2196F3');
      }
      .width('100%')
      .padding(8)
      .backgroundColor('#F5F5F5')
      .borderRadius(4);
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8);
  }

  /**
   * 功能项构建器
   */
  @Builder
  featureItem(icon: string, title: string, description: string) {
    Row({ space: 12 }) {
      Text(icon)
        .fontSize(20);
      
      Column({ space: 4 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold);
        
        Text(description)
          .fontSize(12)
          .fontColor('#666666');
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);
    }
    .width('100%')
    .padding(8);
  }

  /**
   * 方法徽章构建器
   */
  @Builder
  methodBadge(method: string) {
    Text(method)
      .fontSize(12)
      .fontColor('#FFFFFF')
      .backgroundColor('#2196F3')
      .borderRadius(4)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 });
  }

  /**
   * 启动服务器
   */
  private async startServer(): Promise<void> {
    if (!this.webdavExample) {
      return;
    }

    try {
      this.serverStatus = '启动中...';
      
      const info = await this.webdavExample.startSimple();
      
      if (info) {
        this.isRunning = true;
        this.serverStatus = '运行中';
        this.serverInfo = `监听地址: http://${info.address}:${info.port}`;
        this.mountPoints = [
          '/photos -> albums',
          '/documents -> docs',
          '/music -> music'
        ];
      } else {
        this.serverStatus = '启动失败';
      }
    } catch (error) {
      console.error('启动服务器失败:', error);
      this.serverStatus = '启动失败';
    }
  }

  /**
   * 停止服务器
   */
  private async stopServer(): Promise<void> {
    if (!this.webdavExample) {
      return;
    }

    try {
      await this.webdavExample.stop();
      this.isRunning = false;
      this.serverStatus = '已停止';
      this.serverInfo = '';
      this.mountPoints = [];
    } catch (error) {
      console.error('停止服务器失败:', error);
    }
  }

  /**
   * 构建测试按钮区域
   */
  @Builder
  buildTestButtons() {
    Column({ space: 12 }) {
      Text('功能测试')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%');

      // 测试按钮行
      Row({ space: 12 }) {
        // OPTIONS 测试按钮
        Button('测试 OPTIONS')
          .width('45%')
          .height(40)
          .backgroundColor('#2196F3')
          .enabled(this.isRunning && !this.isTesting)
          .onClick(() => {
            this.testOptionsRequest();
          });

        // PROPFIND 测试按钮
        Button('测试 PROPFIND')
          .width('45%')
          .height(40)
          .backgroundColor('#4CAF50')
          .enabled(this.isRunning && !this.isTesting)
          .onClick(() => {
            this.testPropfindRequest();
          });
      }
      .width('100%')
      .justifyContent(FlexAlign.Center);

      // 更多测试按钮
      Row({ space: 12 }) {
        // GET 测试按钮
        Button('测试 GET')
          .width('45%')
          .height(40)
          .backgroundColor('#FF9800')
          .enabled(this.isRunning && !this.isTesting)
          .onClick(() => {
            this.testGetRequest();
          });

        // MKCOL 测试按钮
        Button('测试 MKCOL')
          .width('45%')
          .height(40)
          .backgroundColor('#9C27B0')
          .enabled(this.isRunning && !this.isTesting)
          .onClick(() => {
            this.testMkcolRequest();
          });
      }
      .width('100%')
      .justifyContent(FlexAlign.Center);

      // 测试结果显示
      if (this.testResult) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text('测试结果:')
              .fontSize(14)
              .fontWeight(FontWeight.Bold);
            
            Blank();
            
            Button('清空')
              .fontSize(12)
              .height(24)
              .backgroundColor('#757575')
              .onClick(() => {
                this.testResult = '';
              });
          }
          .width('100%');

          Scroll() {
            Text(this.testResult)
              .fontSize(12)
              .fontColor('#333333')
              .width('100%');
          }
          .width('100%')
          .height(200)
          .backgroundColor('#F5F5F5')
          .borderRadius(4)
          .padding(8);
        }
        .width('100%')
        .padding(8)
        .backgroundColor('#FFFFFF')
        .borderRadius(4);
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8);
  }

  /**
   * 测试 OPTIONS 请求
   */
  private async testOptionsRequest(): Promise<void> {
    if (!this.isRunning) {
      this.testResult = '错误: 服务器未启动';
      return;
    }

    this.isTesting = true;
    this.testResult = '正在发送 OPTIONS 请求...\n';

    try {
      this.httpRequest = http.createHttp();
      
      const url = `http://127.0.0.1:${this.port}/photos`;
      
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.OPTIONS,
        header: {
          'Content-Type': 'application/xml'
        }
      });

      this.testResult += `请求URL: ${url}\n`;
      this.testResult += `状态码: ${response.responseCode}\n`;
      this.testResult += `响应头:\n`;
      
      if (response.header) {
        const headers = response.header as Record<string, string>;
        Object.keys(headers).forEach((key: string) => {
          this.testResult += `  ${key}: ${headers[key]}\n`;
        });
      }
      
      this.testResult += `\n✅ OPTIONS 请求成功`;
    } catch (error) {
      this.testResult += `\n❌ OPTIONS 请求失败: ${JSON.stringify(error)}`;
    } finally {
      if (this.httpRequest) {
        this.httpRequest.destroy();
        this.httpRequest = null;
      }
      this.isTesting = false;
    }
  }

  /**
   * 测试 PROPFIND 请求
   */
  private async testPropfindRequest(): Promise<void> {
    if (!this.isRunning) {
      this.testResult = '错误: 服务器未启动';
      return;
    }

    this.isTesting = true;
    this.testResult = '正在发送 PROPFIND 请求...\n';

    try {
      this.httpRequest = http.createHttp();
      
      const url = `http://127.0.0.1:${this.port}/`;
      
      // PROPFIND 请求体
      const propfindXml = `<?xml version="1.0" encoding="utf-8"?>
<propfind xmlns="DAV:">
  <allprop/>
</propfind>`;
      
      const response = await this.httpRequest.request(url, {
        method: 'PROPFIND' as http.RequestMethod,
        header: {
          'Content-Type': 'application/xml; charset=utf-8',
          'Depth': '1'
        },
        extraData: propfindXml
      });

      this.testResult += `请求URL: ${url}\n`;
      this.testResult += `请求方法: PROPFIND\n`;
      this.testResult += `请求头: Depth: 1\n`;
      this.testResult += `状态码: ${response.responseCode}\n`;
      this.testResult += `\n响应头:\n`;
      
      if (response.header) {
        const headers = response.header as Record<string, string>;
        Object.keys(headers).forEach((key: string) => {
          this.testResult += `  ${key}: ${headers[key]}\n`;
        });
      }
      
      this.testResult += `\n响应体:\n`;
      if (response.result) {
        this.testResult += `${response.result}\n`;
      }
      
      this.testResult += `\n✅ PROPFIND 请求成功`;
    } catch (error) {
      this.testResult += `\n❌ PROPFIND 请求失败: ${JSON.stringify(error)}`;
    } finally {
      if (this.httpRequest) {
        this.httpRequest.destroy();
        this.httpRequest = null;
      }
      this.isTesting = false;
    }
  }

  /**
   * 测试 GET 请求
   */
  private async testGetRequest(): Promise<void> {
    if (!this.isRunning) {
      this.testResult = '错误: 服务器未启动';
      return;
    }

    this.isTesting = true;
    this.testResult = '正在发送 GET 请求...\n';

    try {
      this.httpRequest = http.createHttp();
      
      const url = `http://127.0.0.1:${this.port}/photos`;
      
      const response = await this.httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json'
        }
      });

      this.testResult += `请求URL: ${url}\n`;
      this.testResult += `状态码: ${response.responseCode}\n`;
      this.testResult += `\n响应头:\n`;
      
      if (response.header) {
        const headers = response.header as Record<string, string>;
        Object.keys(headers).forEach((key: string) => {
          this.testResult += `  ${key}: ${headers[key]}\n`;
        });
      }
      
      this.testResult += `\n响应体:\n`;
      if (response.result) {
        this.testResult += `${response.result}\n`;
      }
      
      this.testResult += `\n✅ GET 请求成功`;
    } catch (error) {
      this.testResult += `\n❌ GET 请求失败: ${JSON.stringify(error)}`;
    } finally {
      if (this.httpRequest) {
        this.httpRequest.destroy();
        this.httpRequest = null;
      }
      this.isTesting = false;
    }
  }

  /**
   * 测试 MKCOL 请求
   */
  private async testMkcolRequest(): Promise<void> {
    if (!this.isRunning) {
      this.testResult = '错误: 服务器未启动';
      return;
    }

    this.isTesting = true;
    this.testResult = '正在发送 MKCOL 请求...\n';

    try {
      this.httpRequest = http.createHttp();
      
      const url = `http://127.0.0.1:${this.port}/photos/test-dir`;
      
      const response = await this.httpRequest.request(url, {
        method: 'MKCOL' as http.RequestMethod,
        header: {
          'Content-Type': 'application/xml'
        }
      });

      this.testResult += `请求URL: ${url}\n`;
      this.testResult += `请求方法: MKCOL\n`;
      this.testResult += `状态码: ${response.responseCode}\n`;
      this.testResult += `\n响应头:\n`;
      
      if (response.header) {
        const headers = response.header as Record<string, string>;
        Object.keys(headers).forEach((key: string) => {
          this.testResult += `  ${key}: ${headers[key]}\n`;
        });
      }
      
      if (response.responseCode === 201) {
        this.testResult += `\n✅ MKCOL 请求成功 - 目录已创建`;
      } else if (response.responseCode === 405) {
        this.testResult += `\n⚠️ MKCOL 请求 - 目录已存在`;
      } else {
        this.testResult += `\n✅ MKCOL 请求完成`;
      }
    } catch (error) {
      this.testResult += `\n❌ MKCOL 请求失败: ${JSON.stringify(error)}`;
    } finally {
      if (this.httpRequest) {
        this.httpRequest.destroy();
        this.httpRequest = null;
      }
      this.isTesting = false;
    }
  }
}
