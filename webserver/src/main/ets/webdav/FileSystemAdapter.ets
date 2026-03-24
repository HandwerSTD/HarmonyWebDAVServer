/**
 * @fileName : FileSystemAdapter.ets
 * @author : @cxy
 * @date : 2025/3/24
 * @description : 文件系统适配器 - 封装HarmonyOS文件操作
 */

import { fileIo } from '@kit.CoreFileKit';

/**
 * 文件/目录信息接口
 */
export interface FileInfo {
  name: string;              // 文件名
  path: string;              // 完整路径
  isDirectory: boolean;      // 是否为目录
  size: number;              // 文件大小（字节）
  lastModified: number;      // 最后修改时间（时间戳）
  createdTime: number;       // 创建时间（时间戳）
  mimeType?: string;         // MIME类型
}

/**
 * 文件系统适配器类
 * 封装HarmonyOS文件操作，提供统一的异步API
 */
export class FileSystemAdapter {
  /**
   * 检查文件/目录是否存在
   * @param path 路径
   * @returns 是否存在
   */
  public static async exists(path: string): Promise<boolean> {
    try {
      return await fileIo.access(path);
    } catch (error) {
      return false;
    }
  }

  /**
   * 获取文件/目录信息
   * @param path 路径
   * @returns 文件信息
   */
  public static async stat(path: string): Promise<FileInfo | null> {
    try {
      const exists = await this.exists(path);
      if (!exists) {
        return null;
      }

      const stat = await fileIo.stat(path);
      const name = path.split('/').pop() || '';
      
      return {
        name: name,
        path: path,
        isDirectory: stat.isDirectory(),
        size: stat.size,
        lastModified: stat.mtime,
        createdTime: stat.ctime,
        mimeType: this.getMimeType(name)
      };
    } catch (error) {
      console.error('获取文件信息失败:', error);
      return null;
    }
  }

  /**
   * 列出目录内容
   * @param dirPath 目录路径
   * @returns 文件信息列表
   */
  public static async listDir(dirPath: string): Promise<FileInfo[]> {
    try {
      const exists = await this.exists(dirPath);
      if (!exists) {
        return [];
      }

      const stat = await fileIo.stat(dirPath);
      if (!stat.isDirectory()) {
        return [];
      }

      const files: FileInfo[] = [];
      const list = await fileIo.listFile(dirPath);

      for (const fileName of list) {
        const filePath = `${dirPath}/${fileName}`;
        const fileInfo = await this.stat(filePath);
        if (fileInfo) {
          files.push(fileInfo);
        }
      }

      return files;
    } catch (error) {
      console.error('列出目录失败:', error);
      return [];
    }
  }

  /**
   * 创建目录
   * @param path 目录路径
   * @returns 是否成功
   */
  public static async mkdir(path: string): Promise<boolean> {
    try {
      const exists = await this.exists(path);
      if (exists) {
        return false; // 已存在
      }

      await fileIo.mkdir(path);
      return true;
    } catch (error) {
      console.error('创建目录失败:', error);
      return false;
    }
  }

  /**
   * 删除文件
   * @param path 文件路径
   * @returns 是否成功
   */
  public static async unlink(path: string): Promise<boolean> {
    try {
      const exists = await this.exists(path);
      if (!exists) {
        return false;
      }

      await fileIo.unlink(path);
      return true;
    } catch (error) {
      console.error('删除文件失败:', error);
      return false;
    }
  }

  /**
   * 删除目录（递归）
   * @param path 目录路径
   * @returns 是否成功
   */
  public static async rmdir(path: string): Promise<boolean> {
    try {
      const exists = await this.exists(path);
      if (!exists) {
        return false;
      }

      const stat = await fileIo.stat(path);
      if (!stat.isDirectory()) {
        return await this.unlink(path);
      }

      // 递归删除目录内容
      const files = await this.listDir(path);
      for (const file of files) {
        if (file.isDirectory) {
          await this.rmdir(file.path);
        } else {
          await this.unlink(file.path);
        }
      }

      // 删除空目录
      await fileIo.rmdir(path);
      return true;
    } catch (error) {
      console.error('删除目录失败:', error);
      return false;
    }
  }

  /**
   * 移动文件/目录
   * @param srcPath 源路径
   * @param destPath 目标路径
   * @returns 是否成功
   */
  public static async move(srcPath: string, destPath: string): Promise<boolean> {
    try {
      const exists = await this.exists(srcPath);
      if (!exists) {
        return false;
      }

      // HarmonyOS没有直接的move API，需要复制后删除
      await fileIo.rename(srcPath, destPath);
      return true;
    } catch (error) {
      console.error('移动文件失败:', error);
      return false;
    }
  }

  /**
   * 复制文件
   * @param srcPath 源路径
   * @param destPath 目标路径
   * @returns 是否成功
   */
  public static async copy(srcPath: string, destPath: string): Promise<boolean> {
    try {
      const exists = await this.exists(srcPath);
      if (!exists) {
        return false;
      }

      const srcFile = await fileIo.open(srcPath, fileIo.OpenMode.READ_ONLY);
      const destFile = await fileIo.open(destPath, 
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);

      try {
        const chunkSize = 64 * 1024; // 64KB
        const srcStat = await fileIo.stat(srcPath);
        let offset = 0;

        while (offset < srcStat.size) {
          const readSize = Math.min(chunkSize, srcStat.size - offset);
          const buffer = new ArrayBuffer(readSize);
          
          await fileIo.read(srcFile.fd, buffer, { offset: offset });
          await fileIo.write(destFile.fd, buffer);
          
          offset += readSize;
        }

        return true;
      } finally {
        await fileIo.close(srcFile.fd);
        await fileIo.close(destFile.fd);
      }
    } catch (error) {
      console.error('复制文件失败:', error);
      return false;
    }
  }

  /**
   * 读取文件内容
   * @param path 文件路径
   * @returns 文件内容
   */
  public static async readFile(path: string): Promise<ArrayBuffer | null> {
    try {
      const exists = await this.exists(path);
      if (!exists) {
        return null;
      }

      const stat = await fileIo.stat(path);
      const file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);

      try {
        const buffer = new ArrayBuffer(stat.size);
        await fileIo.read(file.fd, buffer);
        return buffer;
      } finally {
        await fileIo.close(file.fd);
      }
    } catch (error) {
      console.error('读取文件失败:', error);
      return null;
    }
  }

  /**
   * 写入文件内容
   * @param path 文件路径
   * @param data 文件内容
   * @returns 是否成功
   */
  public static async writeFile(path: string, data: ArrayBuffer): Promise<boolean> {
    try {
      const file = await fileIo.open(path, 
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);

      try {
        await fileIo.write(file.fd, data);
        return true;
      } finally {
        await fileIo.close(file.fd);
      }
    } catch (error) {
      console.error('写入文件失败:', error);
      return false;
    }
  }

  /**
   * 获取MIME类型
   * @param fileName 文件名
   * @returns MIME类型
   */
  private static getMimeType(fileName: string): string {
    const ext = fileName.split('.').pop()?.toLowerCase() || '';
    const mimeTypes: Record<string, string> = {
      'txt': 'text/plain',
      'html': 'text/html',
      'htm': 'text/html',
      'css': 'text/css',
      'js': 'application/javascript',
      'json': 'application/json',
      'xml': 'application/xml',
      'pdf': 'application/pdf',
      'zip': 'application/zip',
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'svg': 'image/svg+xml',
      'webp': 'image/webp',
      'mp3': 'audio/mpeg',
      'mp4': 'video/mp4',
      'avi': 'video/x-msvideo',
      'mov': 'video/quicktime',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
    };
    return mimeTypes[ext] || 'application/octet-stream';
  }

  /**
   * 规范化路径（移除多余的斜杠和点）
   * @param path 路径
   * @returns 规范化后的路径
   */
  public static normalizePath(path: string): string {
    // 移除多余的斜杠
    let normalized = path.replace(/\/+/g, '/');
    
    // 处理 ./ 和 ../
    const parts = normalized.split('/').filter(part => part !== '' && part !== '.');
    const result: string[] = [];
    
    for (const part of parts) {
      if (part === '..') {
        if (result.length > 0) {
          result.pop();
        }
      } else {
        result.push(part);
      }
    }
    
    return '/' + result.join('/');
  }

  /**
   * 连接路径
   * @param base 基础路径
   * @param relative 相对路径
   * @returns 连接后的路径
   */
  public static joinPath(base: string, relative: string): string {
    const baseEndsWithSlash = base.endsWith('/');
    const relativeStartsWithSlash = relative.startsWith('/');
    
    if (baseEndsWithSlash && relativeStartsWithSlash) {
      return base + relative.substring(1);
    } else if (!baseEndsWithSlash && !relativeStartsWithSlash) {
      return base + '/' + relative;
    } else {
      return base + relative;
    }
  }
}
