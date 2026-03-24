/**
 * @fileName : HttpRequest.ets
 * @author : @cxy
 * @date : 2025/8/15
 * @description : HTTP 请求解析类
 */
import { Utils } from "./Utils";
import { socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { UploadedFile } from "./middleware/fileUpload";

/**
 * 上传文件接口定义（基础）
 */
export interface File {
  fieldName: string; // 表单字段名
  fileName: string; // 文件名
  contentType: string; // 文件类型
  data: ArrayBuffer; // 文件数据
  name?: string; // 兼容 UploadedFile
  size?: number; // 兼容 UploadedFile
  mimetype?: string; // 兼容 UploadedFile
}


/**
 * 数据回调函数类型
 */
export type DataCallback = (chunk: ArrayBuffer) => void;

/**
 * 结束回调函数类型
 */
export type EndCallback = () => void;

/**
 * 错误回调函数类型
 */
export type ErrorCallback = (error: BusinessError) => void;

/**
 * HTTP请求类
 * 用于解析和处理HTTP请求数据
 * 支持流式Body消费
 */
export class HttpRequest {
  public method: string = ''; // HTTP请求方法（GET、POST等）
  public path: string = ''; // 请求路径（不包含查询字符串）
  public version: string = ''; // HTTP版本
  public url: string = ''; // 完整的URL路径（包含查询字符串）
  public ip: string = ''; // 客户端IP地址
  public headers: Map<string, string> = new Map(); // 请求头集合
  public body: ESObject = {}; // 解析后的请求体数据
  public query: Map<string, string> = new Map(); // 查询字符串参数
  public params: Record<string, string> = {}; // 路由参数
  public files: Record<string, File | UploadedFile> = {}; // 上传的文件（支持两种类型）
  private rawBody: ArrayBuffer = new ArrayBuffer(0); // 原始请求体数据
  
  // 流式传输相关属性
  private _streamingEnabled: boolean = false; // 是否启用流式模式
  private dataCallbacks: DataCallback[] = []; // 数据回调列表
  private endCallbacks: EndCallback[] = []; // 结束回调列表
  private errorCallbacks: ErrorCallback[] = []; // 错误回调列表
  private receivedBytes: number = 0; // 已接收的字节数

  /**
   * 构造函数
   * @param data Socket消息信息
   */
  constructor(data: socket.SocketMessageInfo) {
    this.parseHeadersAndPath(data.message);
    this.parseClientInfo(data.remoteInfo);
  }

  /**
   * 获取请求的User-Agent
   * @returns User-Agent字符串
   */
  public get userAgent(): string {
    return this.get('user-agent') || '';
  }

  /**
   * 获取请求的Referer
   * @returns Referer字符串
   */
  public get referer(): string {
    return this.get('referer') || this.get('referrer') || '';
  }

  /**
   * 获取请求的Content-Length
   * @returns 内容长度
   */
  public get contentLength(): number {
    const length = this.get('content-length');
    return length ? parseInt(length) : 0;
  }

  /**
   * 解析请求体数据
   * 根据Content-Type自动选择解析方式
   */
  public parseBody(): void {
    const contentType = this.headers.get('content-type');
    const transferEncoding = this.headers.get('transfer-encoding');

    // 如果是分块传输，先解码分块数据
    if (transferEncoding && transferEncoding.toLowerCase().includes('chunked')) {
      this.rawBody = this.decodeChunkedBody(this.rawBody);
    }

    if (contentType && this.rawBody.byteLength > 0) {
      if (contentType.includes('application/json')) {
        try {
          const bodyStr = Utils.arrayBufferToStr(this.rawBody);
          this.body = JSON.parse(bodyStr);
        } catch (error) {
          console.error("Failed to parse JSON body", error);
          this.body = {};
        }
      } else if (contentType.includes('application/x-www-form-urlencoded')) {
        const bodyStr = Utils.arrayBufferToStr(this.rawBody);
        const params: Record<string, string> = {};
        const pairs = bodyStr.split('&');
        for (const pair of pairs) {
          const parts = pair.split('=');
          if (parts.length === 2) {
            const key = decodeURIComponent(parts[0].replace(/\+/g, ' '));
            const value = decodeURIComponent(parts[1].replace(/\+/g, ' '));
            params[key] = value;
          }
        }
        this.body = params;
      } else if (contentType.includes('multipart/form-data')) {
        this.parseMultipartFormData(contentType, this.rawBody);
      } else if (contentType.includes('text/plain')) {
        this.body = Utils.arrayBufferToStr(this.rawBody);
      } else {
        // 对于其他类型，保持原始数据
        this.body = this.rawBody
      }
    }
  }

  /**
   * 获取原始请求体数据
   * @returns 原始ArrayBuffer数据
   */
  public getRawBody(): ArrayBuffer {
    return this.rawBody;
  }

  /**
   * 获取请求头
   * @param headerName 请求头名称
   * @returns 请求头值
   */
  public get(headerName: string): string | undefined {
    return this.headers.get(headerName.toLowerCase());
  }

  /**
   * 检查是否为指定的Content-Type
   * @param type 要检查的内容类型
   * @returns 是否匹配
   */
  public is(type: string): boolean {
    const contentType = this.get('content-type');
    return contentType ? contentType.includes(type) : false;
  }

  /**
   * 解码分块传输编码的请求体
   * @param chunkedBody 分块编码的数据
   * @returns 解码后的完整数据
   */
  private decodeChunkedBody(chunkedBody: ArrayBuffer): ArrayBuffer {
    const bodyStr = Utils.arrayBufferToStr(chunkedBody);
    const chunks: string[] = [];
    let offset = 0;

    while (offset < bodyStr.length) {
      // 查找块大小行的结束位置
      const crlfIndex = bodyStr.indexOf('\r\n', offset);
      if (crlfIndex === -1) {
        break;
      }

      // 解析块大小（十六进制）
      const chunkSizeStr = bodyStr.substring(offset, crlfIndex);
      const chunkSize = parseInt(chunkSizeStr, 16);

      // 如果块大小为0，表示传输结束
      if (chunkSize === 0) {
        break;
      }

      // 提取块数据
      const chunkStart = crlfIndex + 2; // 跳过 \r\n
      const chunkEnd = chunkStart + chunkSize;
      const chunk = bodyStr.substring(chunkStart, chunkEnd);
      chunks.push(chunk);

      // 移动到下一个块（跳过块数据后的 \r\n）
      offset = chunkEnd + 2;
    }

    // 合并所有块
    const decodedBody = chunks.join('');
    return Utils.strToArrayBuffer(decodedBody);
  }

  /**
   * 解析HTTP请求头和路径
   * @param requestData 原始请求数据
   */
  private parseHeadersAndPath(requestData: ArrayBuffer): void {
    const requestStr = Utils.arrayBufferToStr(requestData)
    const headerEndIndex = requestStr.indexOf('\r\n\r\n');

    if (headerEndIndex === -1) {
      // Invalid request, no headers found
      return;
    }

    const headerStr = requestStr.substring(0, headerEndIndex);
    const bodyData = requestData.slice(headerEndIndex + 4);

    const headerLines = headerStr.split('\r\n');
    const requestLine = headerLines.shift();

    if (requestLine) {
      const requestLineParts = requestLine.split(' ');
      this.method = requestLineParts[0];
      const fullPath = requestLineParts[1];
      this.version = requestLineParts[2];

      this.url = fullPath; // 保存完整URL

      const queryIndex = fullPath.indexOf('?');
      if (queryIndex !== -1) {
        this.path = fullPath.substring(0, queryIndex);
        const queryString = fullPath.substring(queryIndex + 1);
        this.parseQuery(queryString);
      } else {
        this.path = fullPath;
      }
    }

    headerLines.forEach(line => {
      const parts = line.split(': ');
      if (parts.length === 2) {
        this.headers.set(parts[0].toLowerCase(), parts[1]);
      }
    });

    if (bodyData.byteLength > 0) {
      this.rawBody = bodyData;
    }
  }

  /**
   * 解析查询字符串参数
   * @param queryString 查询字符串
   */
  private parseQuery(queryString: string): void {
    const params = queryString.split('&');
    params.forEach(param => {
      const parts = param.split('=');
      if (parts.length === 2) {
        this.query.set(decodeURIComponent(parts[0]), decodeURIComponent(parts[1]));
      }
    });
  }

  /**
   * 从Content-Type中解析boundary
   * @param contentType Content-Type头部值
   * @returns boundary字符串或null
   */
  private parseBoundary(contentType: string): string | null {
    const match = contentType.match(/boundary=(.+)/);
    return match ? match[1].trim() : null;
  }

  /**
   * 解析multipart/form-data格式的请求体
   * @param contentType Content-Type头部值
   * @param body 请求体数据
   */
  private parseMultipartFormData(contentType: string, body: ArrayBuffer): void {
    this.body = {}; // 初始化body为空对象
    const boundary = this.parseBoundary(contentType);
    if (!boundary) {
      return;
    }

    const data = new Uint8Array(body)
    const parts = this.splitMultipartData(data, boundary);
    for (const part of parts) {
      let headersEnd = -1;
      const CRLF_CRLF = new Uint8Array([0x0D, 0x0A, 0x0D, 0x0A]);
      for (let i = 0; i <= part.length - CRLF_CRLF.length; i++) {
        if (part[i] === CRLF_CRLF[0] &&
          part[i + 1] === CRLF_CRLF[1] &&
          part[i + 2] === CRLF_CRLF[2] &&
          part[i + 3] === CRLF_CRLF[3]) {
          headersEnd = i;
          break;
        }
      }

      if (headersEnd === -1) {
        continue;
      }

      const headers = Utils.uint8ToStr(part.slice(0, headersEnd));
      const content = part.slice(headersEnd + 4); // Skip CRLF CRLF
      const dispositionMatch =
        headers.match(/Content-Disposition: form-data; name=\"([^\"]+)\"(?:; filename=\"([^\"]+)\")?/);
      if (dispositionMatch) {
        const name = dispositionMatch[1];
        const filename = dispositionMatch[2];
        const contentTypeMatch = headers.match(/Content-Type: ([^\r\n]+)/);
        const contentTypeHeader = contentTypeMatch ? contentTypeMatch[1].trim() : 'application/octet-stream';

        if (filename) {
          this.files[name] = {
            fieldName: name,
            fileName: filename,
            contentType: contentTypeHeader,
            data: content.buffer as ArrayBuffer
          };
        } else {
          this.body[name] = Utils.uint8ToStr(content);
        }
      }
    }
  }

  private splitMultipartData(data: Uint8Array, boundary: string): Uint8Array[] {
    const boundaryBytes = Utils.strToUint8Array(`--${boundary}`);
    const parts: Uint8Array[] = [];
    let startIndex = 0;

    while (true) {
      const endIndex = this.findBoundary(data, boundaryBytes, startIndex);
      if (endIndex === -1) {
        break;
      }

      if (endIndex > startIndex) {
        parts.push(data.slice(startIndex, endIndex));
      }
      startIndex = endIndex + boundaryBytes.length + 2; // +2 for CRLF
    }
    return parts.filter(part => part.length > 0);
  }

  private findBoundary(data: Uint8Array, boundary: Uint8Array, start: number): number {
    for (let i = start; i <= data.length - boundary.length; i++) {
      let match = true;
      for (let j = 0; j < boundary.length; j++) {
        if (data[i + j] !== boundary[j]) {
          match = false;
          break;
        }
      }
      if (match) {
        // Check for CRLF before the boundary, and CRLF after the boundary
        if (i > 0 && data[i - 1] === 0x0A && data[i - 2] === 0x0D) {
          return i - 2; // Return start of CRLF before boundary
        }
      }
    }
    return -1;
  }

  /**
   * 解析客户端信息
   * 包括IP地址、代理信息等
   * @param info Socket远程信息
   */
  private parseClientInfo(info: socket.SocketRemoteInfo): void {
    // 解析IP地址
    if (info) {
      this.ip = info.address;
    }

    // 检查代理头部
    const xForwardedFor = this.get('x-forwarded-for');
    if (xForwardedFor) {
      const ips = xForwardedFor.split(',').map(ip => ip.trim());
      if (ips.length > 0) {
        this.ip = ips[0]; // 使用第一个IP作为真实IP
      }
    }

    const xRealIp = this.get('x-real-ip');
    if (xRealIp) {
      this.ip = xRealIp;
    }
  }

  // ==================== 流式传输方法 ====================

  /**
   * 启用流式模式
   * 调用此方法后，框架将不会自动解析Body，而是通过回调分发数据
   * @returns 当前请求对象（支持链式调用）
   */
  public enableStreaming(): HttpRequest {
    this._streamingEnabled = true;
    return this;
  }

  /**
   * 检查是否启用了流式模式
   * @returns 是否启用流式模式
   */
  public isStreamingEnabled(): boolean {
    return this._streamingEnabled;
  }

  /**
   * 注册数据回调
   * 当收到Body数据块时触发
   * @param callback 数据回调函数
   */
  public onData(callback: DataCallback): void {
    this.dataCallbacks.push(callback);
  }

  /**
   * 注册结束回调
   * 当Body接收完毕时触发
   * @param callback 结束回调函数
   */
  public onEnd(callback: EndCallback): void {
    this.endCallbacks.push(callback);
  }

  /**
   * 注册错误回调
   * 当传输过程中发生错误时触发
   * @param callback 错误回调函数
   */
  public onError(callback: ErrorCallback): void {
    this.errorCallbacks.push(callback);
  }

  /**
   * 触发数据回调（由HttpServer调用）
   * @param chunk 数据块
   */
  public emitData(chunk: ArrayBuffer): void {
    this.receivedBytes += chunk.byteLength;
    
    // 如果未启用流式模式，累积到rawBody
    if (!this._streamingEnabled) {
      this.rawBody = Utils.mergeArrayBuffers(this.rawBody, chunk);
    }
    
    // 触发所有数据回调
    for (const callback of this.dataCallbacks) {
      try {
        callback(chunk);
      } catch (error) {
        console.error('数据回调执行错误:', error);
      }
    }
  }

  /**
   * 触发结束回调（由HttpServer调用）
   */
  public emitEnd(): void {
    // 如果未启用流式模式，自动解析Body
    if (!this._streamingEnabled && this.rawBody.byteLength > 0) {
      this.parseBody();
    }
    
    // 触发所有结束回调
    for (const callback of this.endCallbacks) {
      try {
        callback();
      } catch (error) {
        console.error('结束回调执行错误:', error);
      }
    }
  }

  /**
   * 触发错误回调（由HttpServer调用）
   * @param error 错误信息
   */
  public emitError(error: BusinessError): void {
    // 触发所有错误回调
    for (const callback of this.errorCallbacks) {
      try {
        callback(error);
      } catch (err) {
        console.error('错误回调执行错误:', err);
      }
    }
  }

  /**
   * 获取已接收的字节数
   * @returns 已接收字节数
   */
  public getReceivedBytes(): number {
    return this.receivedBytes;
  }

  /**
   * 获取期望接收的总字节数（Content-Length）
   * @returns 期望字节数，0表示未知
   */
  public getExpectedBytes(): number {
    return this.contentLength;
  }

  /**
   * 检查是否接收完毕
   * @returns 是否接收完毕
   */
  public isComplete(): boolean {
    const expected = this.getExpectedBytes();
    return expected > 0 && this.receivedBytes >= expected;
  }
}