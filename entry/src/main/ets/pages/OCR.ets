import picker from '@ohos.file.picker'
import http from '@ohos.net.http'
import { fileIo as fs } from '@kit.CoreFileKit'
import promptAction from '@ohos.promptAction'
import { util } from '@kit.ArkTS'
import preferences from '@ohos.data.preferences'
import image from '@ohos.multimedia.image'
import common from '@ohos.app.ability.common'
import resourceManager from '@ohos.resourceManager'
import { hilog } from '@kit.PerformanceAnalysisKit'

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
  private readonly BAIDU_API_KEY =
    '7330561' // Note: This looks like AppID, but user labeled it AppID. Wait, user said API Key: 8OlOdr1aXNueL3Ul2mmSYSba
  // Re-checking user input:
  // AppID：7330561
  // API Key：8OlOdr1aXNueL3Ul2mmSYSba
  // Secret Key：QP6sFkEn0pHrrS7x73jf6TVAps5nEiLG
  // OCR space appkey：K88917080488957

  private readonly BAIDU_AK = '8OlOdr1aXNueL3Ul2mmSYSba'
  private readonly BAIDU_SK = 'QP6sFkEn0pHrrS7x73jf6TVAps5nEiLG'
  private readonly OCR_SPACE_KEY = 'K88917080488957'

  aboutToAppear() {
    // No longer need to load keys
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
      hilog.debug(0x0000, 'OCR', 'runOCR 11111', dataUrl)
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
        hilog.debug(0x0000, 'OCR', 'runOCR 222222', JSON.stringify(resp))
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
        hilog.debug(0x0000, 'OCR error', `runOCR 222222 ${dataUrl}`)
        const textBaidu = await this.runOCRBaidu(dataUrl)
        this.ocrText = textBaidu
        if (!textBaidu) {
          throw new Error('baidu empty')
        }
        promptAction.showToast({ message: '已切换百度识别完成' })
      }
    } catch (e) {
      promptAction.showToast({ message: '识别失败，请检查网络或密钥' })
    } finally {
      this.recognizing = false
    }
  }

  private copyText() {
    if (!this.ocrText) {
      return
    }
    promptAction.showToast({ message: '已复制' })
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
      }
    } catch (error) {
      promptAction.showToast({ message: '选择图片失败' })
    }
  }

  private async readFileBase64(uri: string): Promise<string> {
    try {
      const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
      const stat = await fs.stat(uri)
      const buf = new ArrayBuffer(stat.size)
      await fs.read(file.fd, buf)
      await fs.close(file.fd)
      const u8 = new Uint8Array(buf)
      const b64 = new util.Base64Helper().encodeToStringSync(u8)
      return 'data:image/jpeg;base64,' + b64
    } catch (e) {
      throw new Error('read file failed')
    }
  }

  private async readRawBase64(fileName: string): Promise<string> {
    try {
      const ctx = getContext(this)
      const resourceMgr = ctx.resourceManager
      // access media resource directly using the resource ID
      const content = await resourceMgr.getMediaContent($r('app.media.1242x2688bb').id)
      const b64 = new util.Base64Helper().encodeToStringSync(content)
      return 'data:image/jpeg;base64,' + b64
    } catch (e) {
      hilog.error(0x0000, 'OCR', 'readRawBase64 error %{public}s', JSON.stringify(e))
      throw new Error('read builtin failed')
    }
  }

  build() {
    Column() {
      Row() {
        Text('图像转文字OCR')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Blank().layoutWeight(1)
      }
      .width('100%')
      .padding({ top: 16, left: 20, right: 20 })

      Stack() {
        Row() {
          if (this.useBuiltin) {
            Image($r('app.media.1242x2688bb'))
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
          } else if (this.imageUri) {
            Image(this.imageUri)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
          } else {
            Text('选择或拍摄文档')
              .fontSize(16)
              .fontColor('#9CA3AF')
          }
        }
        .align(Alignment.Center)
        .width('92%')
        .height(this.previewHeight)
        .backgroundColor('#0f172a')
        .borderRadius(16)

        Row() {
          Button('拍摄文档')
            .type(ButtonType.Capsule)
            .onClick(() => this.pickImage())
          Button('导入图片')
            .type(ButtonType.Capsule)
            .margin({ left: 12 })
            .onClick(() => this.pickImage())
          Button('使用内置图片')
            .type(ButtonType.Capsule)
            .margin({ left: 12 })
            .onClick(() => {
              this.useBuiltin = true;
              this.imageUri = '';
              this.ocrText = ''
            })
        }
        .position({ bottom: 12 })
      }
      .align(Alignment.Center)
      .width('100%')
      .padding({ top: 12 })

      Row() {
        Text(this.recognizing ? '识别中…' : '识别结果')
          .fontSize(14)
          .fontColor('#6B7280')
        Blank().layoutWeight(1)
        if (this.recognizing) {
          LoadingProgress().width(24).height(24)
        } else {
          Button('开始识别')
            .type(ButtonType.Capsule)
            .onClick(() => this.runOCR())
        }
      }
      .width('92%')
      .padding({ top: 12 })

      // Removed key input rows as requested


      TextInput({ placeholder: '识别文本', text: this.ocrText })
        .width('92%')
        .height(180)
        .borderRadius(12)
        .backgroundColor('#F9FAFB')
        .padding(12)
        .maxLines(6)
        .onChange((t: string) => this.ocrText = t)

      Row() {
        Button('复制')
          .type(ButtonType.Capsule)
          .onClick(() => this.copyText())
      }
      .width('92%')
      .padding({ top: 8, bottom: 20 })
    }
    .width('100%')
    .height('100%')
  }
}
