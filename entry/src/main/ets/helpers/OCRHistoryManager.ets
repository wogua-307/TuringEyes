import preferences from '@ohos.data.preferences'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

export interface OCRRecord {
  id: string
  timestamp: number
  imagePath: string
  text: string
}

export class OCRHistoryManager {
  private static readonly PREF_NAME = 'ocr_history'
  private static readonly KEY_RECORDS = 'records'
  private static readonly DIR_NAME = 'ocr_history_images'

  static async saveRecord(context: common.UIAbilityContext, imageUri: string, text: string): Promise<void> {
    try {
      const timestamp = Date.now()
      const id = `${timestamp}`
      
      // 1. Save Image to sandbox
      const filesDir = context.filesDir
      const targetDir = `${filesDir}/${OCRHistoryManager.DIR_NAME}`
      if (!fs.accessSync(targetDir)) {
        fs.mkdirSync(targetDir)
      }
      const targetPath = `${targetDir}/${id}.jpg`
      
      // Copy or write file
      const file = fs.openSync(imageUri, fs.OpenMode.READ_ONLY)
      const dest = fs.openSync(targetPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      
      const stat = fs.statSync(file.fd)
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      fs.writeSync(dest.fd, buf)
      
      fs.closeSync(file.fd)
      fs.closeSync(dest.fd)

      // 2. Save Metadata
      const record: OCRRecord = {
        id,
        timestamp,
        imagePath: targetPath,
        text
      }
      
      const prefs = await preferences.getPreferences(context, OCRHistoryManager.PREF_NAME)
      const json = await prefs.get(OCRHistoryManager.KEY_RECORDS, '[]') as string
      const records = JSON.parse(json) as OCRRecord[]
      records.unshift(record) // Add to top
      
      await prefs.put(OCRHistoryManager.KEY_RECORDS, JSON.stringify(records))
      await prefs.flush()
      
    } catch (e) {
      hilog.error(0x0000, 'OCRHistory', 'saveRecord error %{public}s', JSON.stringify(e))
    }
  }

  static async getRecords(context: common.UIAbilityContext): Promise<OCRRecord[]> {
    try {
      const prefs = await preferences.getPreferences(context, OCRHistoryManager.PREF_NAME)
      const json = await prefs.get(OCRHistoryManager.KEY_RECORDS, '[]') as string
      return JSON.parse(json) as OCRRecord[]
    } catch (e) {
      return []
    }
  }

  static async clearHistory(context: common.UIAbilityContext): Promise<void> {
    try {
       const prefs = await preferences.getPreferences(context, OCRHistoryManager.PREF_NAME)
       await prefs.delete(OCRHistoryManager.KEY_RECORDS)
       await prefs.flush()
       
       // Cleanup files
       const targetDir = `${context.filesDir}/${OCRHistoryManager.DIR_NAME}`
       if (fs.accessSync(targetDir)) {
         fs.rmdirSync(targetDir)
       }
    } catch (e) {
       hilog.error(0x0000, 'OCRHistory', 'clearHistory error %{public}s', JSON.stringify(e))
    }
  }
}
