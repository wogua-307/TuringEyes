import picker from '@ohos.file.picker'
import http from '@ohos.net.http'
import { fileIo as fs } from '@kit.CoreFileKit'
import promptAction from '@ohos.promptAction'
import { util } from '@kit.ArkTS'
import { pasteboard } from '@kit.BasicServicesKit';
import preferences from '@ohos.data.preferences'
import image from '@ohos.multimedia.image'
import common from '@ohos.app.ability.common'
import resourceManager from '@ohos.resourceManager'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import router from '@ohos.router'
import { OCRHistoryManager, OCRRecord } from '../helpers/OCRHistoryManager'

interface ParsedResult {
  ParsedText?: string
}

interface OCRResponse {
  ParsedResults?: Array<ParsedResult>
}

interface BaiduTokenResponse {
  access_token?: string
  expires_in?: number
  refresh_token?: string
  scope?: string
  session_key?: string
  session_secret?: string
}

interface WordResult {
  words: string
}

interface BaiduOCRResponse {
  words_result?: Array<WordResult>
  words_result_num?: number
  log_id?: number
  direction?: number
}

@Entry
@Component
export struct OCRPage {
  @State private imageUri: string = ''
  @State private ocrText: string = ''
  @State private recognizing: boolean = false
  @State private previewHeight: number = 380
  @State private lang: string = 'chs'
  @State private useBuiltin: boolean = false
  // Hardcoded keys as requested
  private readonly BAIDU_AK = '8OlOdr1aXNueL3Ul2mmSYSba'
  private readonly BAIDU_SK = 'QP6sFkEn0pHrrS7x73jf6TVAps5nEiLG'
  private readonly OCR_SPACE_KEY = 'K88917080488957'

  onPageShow() {
    const params = router.getParams() as Record<string, string>
    if (params && params.selectedRecord) {
      try {
        const item = JSON.parse(params.selectedRecord) as OCRRecord
        this.ocrText = item.text
        this.imageUri = 'file://' + item.imagePath
        this.useBuiltin = false
      } catch (e) {
        hilog.error(0x0000, 'OCR', 'parse history param error %{public}s', JSON.stringify(e))
      }
    }
  }

  private openHistory() {
    router.pushUrl({ url: 'pages/OCRHistory' })
  }

  private async getBaiduToken(): Promise<string> {
    if (!this.BAIDU_AK || !this.BAIDU_SK) {
      throw new Error('missing baidu keys')
    }
    const url =
      `https://aip.baidubce.com/oauth/2.0/token?grant_type=client_credentials&client_id=${encodeURIComponent(this.BAIDU_AK)}&client_secret=${encodeURIComponent(this.BAIDU_SK)}`
    const httpClient = http.createHttp()
    try {
      const resp = await httpClient.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        expectDataType: http.HttpDataType.OBJECT
      })
      if (resp.responseCode !== 200) {
        throw new Error('token http error')
      }
      const result = resp.result as BaiduTokenResponse
      const token = result.access_token || ''
      if (!token) {
        throw new Error('no token')
      }
      return token
    } finally {
      httpClient.destroy()
    }
  }

  private async runOCRBaidu(dataUrl: string): Promise<string> {
    const token = await this.getBaiduToken()
    const base64 = dataUrl.includes(',') ? dataUrl.split(',')[1] : dataUrl
    const httpClient = http.createHttp()
    try {
      const body = `image=${encodeURIComponent(base64)}&language_type=CHN_ENG&detect_direction=true`
      const url = `https://aip.baidubce.com/rest/2.0/ocr/v1/general_basic?access_token=${encodeURIComponent(token)}`
      const resp = await httpClient.request(url, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/x-www-form-urlencoded' },
        extraData: body,
        expectDataType: http.HttpDataType.OBJECT
      })
      if (resp.responseCode !== 200) {
        throw new Error('baidu http error')
      }
      const result = resp.result as BaiduOCRResponse
      const words = result.words_result || []
      const joined = words.map(w => w.words || '').join('\n')
      return joined
    } finally {
      httpClient.destroy()
    }
  }

  private async runOCR() {
    this.recognizing = true
    try {
      promptAction.showToast({ message: '开始识别' })
      let dataUrl: string
      if (this.useBuiltin) {
        dataUrl = await this.readRawBase64('1242x2688bb.png')
      } else {
        if (!this.imageUri) {
          promptAction.showToast({ message: '请先选择图片' })
          this.recognizing = false
          return
        }
        dataUrl = await this.readFileBase64(this.imageUri)
      }
      try {
        const httpClient = http.createHttp()
        const apiKey = this.OCR_SPACE_KEY
        const body =
          `apikey=${encodeURIComponent(apiKey)}&language=${this.lang}&isOverlayRequired=false&base64Image=${encodeURIComponent(dataUrl)}`
        const resp = await httpClient.request('https://api.ocr.space/parse/image', {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/x-www-form-urlencoded' },
          extraData: body,
          expectDataType: http.HttpDataType.OBJECT
        })
        httpClient.destroy()
        if (resp.responseCode === 200) {
          const result = resp.result as OCRResponse
          const arr = result.ParsedResults || []
          const text = arr.length > 0 ? (arr[0].ParsedText || '') : ''
          if (text) {
            this.ocrText = text
            promptAction.showToast({ message: 'OCR.Space识别完成' })
            return
          }
        }
        throw new Error('space failed')
      } catch {
        const textBaidu = await this.runOCRBaidu(dataUrl)
        this.ocrText = textBaidu
        if (!textBaidu) {
          throw new Error('baidu empty')
        }
        // promptAction.showToast({ message: '已切换百度识别完成' })
      }
    } catch (e) {
      promptAction.showToast({ message: '识别失败，请检查网络' })
    } finally {
      this.recognizing = false
      if (this.ocrText && !this.useBuiltin && this.imageUri) {
        const ctx = getContext(this) as common.UIAbilityContext
        OCRHistoryManager.saveRecord(ctx, this.imageUri, this.ocrText)
      }
    }
  }

  private dismissKeyboard() {
    // 通过让输入框失去焦点来隐藏软键盘
    // 在页面中需要有一个输入框的引用，这里使用空操作
    // 实际应用中可以通过控制输入框的焦点状态来隐藏键盘
  }

  private copyText() {
    if (!this.ocrText) {
      return
    }

    const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.ocrText)
    const systemPasteboard = pasteboard.getSystemPasteboard()
    systemPasteboard.setData(pasteboardData) //将数据放入剪切板
    systemPasteboard.getData().then((data) => {
      if (data) {
        promptAction.showToast({ message: "复制成功" })
      } else {
        promptAction.showToast({ message: "复制失败" })
      }
    })
  }

  private async pickImage(): Promise<void> {
    try {
      const photoSelectOptions = new picker.PhotoSelectOptions()
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE
      photoSelectOptions.maxSelectNumber = 1

      const photoPicker = new picker.PhotoViewPicker()
      const result = await photoPicker.select(photoSelectOptions)

      if (result && result.photoUris && result.photoUris.length > 0) {
        this.imageUri = result.photoUris[0]
        this.useBuiltin = false
        this.ocrText = ''
        this.runOCR()
      }
    } catch (error) {
      promptAction.showToast({ message: '选择图片失败' })
    }
  }

  private async compressToUnder1MB(buffer: ArrayBuffer): Promise<string> {
    try {
      const src = image.createImageSource(buffer)
      // Check original size estimate
      const info = await src.getImageInfo()
      let quality = 80
      let scale = 1.0
      const packer = image.createImagePacker()

      // Try compressing with quality first
      while (quality > 0) {
        const op: image.PackingOption = { format: 'image/jpeg', quality: quality }
        // If image is too large, we might need to resize.
        // For simplicity, let's try strict resizing if dimensions are huge.
        if (info.size.width > 2000 || info.size.height > 2000) {
          scale = 0.5
        }

        let pm = await src.createPixelMap()
        if (scale < 1.0) {
          pm.scale(scale, scale)
        }
        const compressed = await packer.packing(pm, op)
        pm.release()

        if (compressed.byteLength < 1000 * 1000) {
          const u8 = new Uint8Array(compressed)
          const b64 = new util.Base64Helper().encodeToStringSync(u8)
          return 'data:image/jpeg;base64,' + b64
        }
        quality -= 20
        if (scale === 1.0 && quality < 40) {
          // if quality dropped low and still too big, force scale down
          scale = 0.7
          quality = 80 // reset quality for scaled image
        } else if (scale < 1.0 && quality < 40) {
          scale *= 0.8 // shrink more
          quality = 80
        }
      }
      // If loop finishes (unlikely to fail reducing enough), just return original as fallback
      const u8 = new Uint8Array(buffer)
      const b64 = new util.Base64Helper().encodeToStringSync(u8)
      return 'data:image/jpeg;base64,' + b64
    } catch (e) {
      hilog.error(0x0000, 'OCR', 'compress error %{public}s', JSON.stringify(e))
      // Fallback
      const u8 = new Uint8Array(buffer)
      const b64 = new util.Base64Helper().encodeToStringSync(u8)
      return 'data:image/jpeg;base64,' + b64
    }
  }

  private async readFileBase64(uri: string): Promise<string> {
    try {
      const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
      const stat = await fs.stat(file.fd)
      const buf = new ArrayBuffer(stat.size)
      await fs.read(file.fd, buf)
      await fs.close(file.fd)
      return await this.compressToUnder1MB(buf)
    } catch (e) {
      hilog.error(0x0000, 'OCR', 'readFileBase64 error %{public}s', JSON.stringify(e))
      throw new Error('read file failed')
    }
  }

  private async readRawBase64(fileName: string): Promise<string> {
    try {
      const ctx = getContext(this)
      const resourceMgr = ctx.resourceManager
      // access media resource directly using the resource ID
      const content = await resourceMgr.getMediaContent($r('app.media.ocr_nor').id)
      const buf = content.buffer as ArrayBuffer
      return await this.compressToUnder1MB(buf)
    } catch (e) {
      hilog.error(0x0000, 'OCR', 'readRawBase64 error %{public}s', JSON.stringify(e))
      throw new Error('read builtin failed')
    }
  }

  build() {
    Stack() {
      Column() {
        // Header
        Row() {
          Text('图像转文字OCR')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
          // Blank()
          // // History icon placeholder
          // Text('🕒')
          //   .fontSize(24)
          //   .onClick(() => {
          //     this.openHistory()
          //   })
        }
        .width('100%')
        .padding({ bottom: 16 })

        // Image Playground
        Stack() {
          if (this.imageUri || this.useBuiltin) {
            Image(this.imageUri || (this.useBuiltin ? $r('app.media.ocr_nor') : ''))
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
          } else {
            Column() {
              Image($r('app.media.ocr_nor'))// Placeholder icon
                .width(48)
                .height(48)
                .fillColor('#3b82f6')
                .margin({ bottom: 8 })
            }.justifyContent(FlexAlign.Center)
          }

          // Blue Frame Overlay
          if (this.imageUri || this.useBuiltin) {
            // Optional frame visual
          }
        }
        .width('100%')
        .height(360)
        .backgroundColor('#f5f5f5')
        .borderRadius(16)
        .clip(true)
        // .border({ width: 2, color: '#3b82f6' }) // Blue border as requested
        .margin({ bottom: 16 })

        // Buttons
        Row() {
          Button('拍摄文档')
            .type(ButtonType.Normal)
            .borderRadius(8)
            .backgroundColor('#3b82f6')
            .fontColor(Color.White)
            .layoutWeight(1)
            .height(44)
            .opacity(this.recognizing ? 0.5 : 1.0)
            .enabled(!this.recognizing)
            .onClick(() => this.pickImage())

          Button('导入图片')
            .type(ButtonType.Normal)
            .borderRadius(8)
            .backgroundColor('#3b82f6')
            .fontColor(Color.White)
            .layoutWeight(1)
            .height(44)
            .margin({ left: 12 })
            .opacity(this.recognizing ? 0.5 : 1.0)
            .enabled(!this.recognizing)
            .onClick(() => this.pickImage())
        }
        .width('100%')
        .margin({ bottom: 16 })

        // Status
        Row() {
          Text(this.recognizing ? '识别中...' : '识别结果')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')
          Blank()
          if (this.recognizing) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color('#3b82f6')
          }
        }
        .width('100%')
        .padding({ bottom: 8 })

        // Result Area
        Stack() {
          TextArea({ placeholder: '', text: this.ocrText })
            .width('100%')
            .height('100%')
            .borderRadius(12)
            .backgroundColor(Color.Transparent)
            .fontColor('#374151')
            .fontSize(16)
            .padding(12)
            .onChange((t: string) => this.ocrText = t)
        }
        .layoutWeight(1)
        .width('100%')
        .backgroundColor(Color.White)
        .borderRadius(12)
        .border({ width: 2, color: 'rgba(232,121,249, 0.3)' }) // Pink/Purple border
        .shadow({ radius: 4, color: 'rgba(232, 121, 249, 0.2)' }) // Glow effect

        Row() {
          Button('复制')
            .fontSize(14)
            .height(32)
            .backgroundColor('#3b82f6')
            .fontColor(Color.White)
            .onClick(() => this.copyText())
        }.justifyContent(FlexAlign.End).width('100%').padding({ top: 8 })

      }
      .padding(16)
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)

      Text('')
        .hitTestBehavior(HitTestMode.Transparent)
        .width('100%')
        .height('100%')
        .onTouch(() => this.dismissKeyboard())
    }
  }
}
